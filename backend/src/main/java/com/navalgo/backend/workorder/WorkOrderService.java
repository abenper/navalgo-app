package com.navalgo.backend.workorder;

import com.navalgo.backend.common.InputSanitizer;
import com.navalgo.backend.fleet.Owner;
import com.navalgo.backend.fleet.OwnerRepository;
import com.navalgo.backend.fleet.Vessel;
import com.navalgo.backend.fleet.VesselRepository;
import com.navalgo.backend.notification.NotificationService;
import com.navalgo.backend.notification.NotificationType;
import com.navalgo.backend.worker.Worker;
import com.navalgo.backend.worker.WorkerRepository;
import org.springframework.security.access.AccessDeniedException;
import jakarta.persistence.EntityNotFoundException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.util.*;

@Service
@Transactional(readOnly = true)
public class WorkOrderService {

    private final WorkOrderRepository workOrderRepository;
    private final OwnerRepository ownerRepository;
    private final VesselRepository vesselRepository;
    private final WorkerRepository workerRepository;
    private final NotificationService notificationService;
    private final WorkOrderMediaService workOrderMediaService;
    private final InputSanitizer inputSanitizer;

    public WorkOrderService(WorkOrderRepository workOrderRepository,
                            OwnerRepository ownerRepository,
                            VesselRepository vesselRepository,
                            WorkerRepository workerRepository,
                            NotificationService notificationService,
                            WorkOrderMediaService workOrderMediaService,
                            InputSanitizer inputSanitizer) {
        this.workOrderRepository = workOrderRepository;
        this.ownerRepository = ownerRepository;
        this.vesselRepository = vesselRepository;
        this.workerRepository = workerRepository;
        this.notificationService = notificationService;
        this.workOrderMediaService = workOrderMediaService;
        this.inputSanitizer = inputSanitizer;
    }

    public List<WorkOrderDto> findAll() {
        return workOrderRepository.findAllByOrderByCreatedAtDesc()
                .stream()
                .map(this::toDto)
                .toList();
    }

    public List<WorkOrderDto> findByWorker(Long workerId) {
        return workOrderRepository.findByAssignedWorkersIdOrderByCreatedAtDesc(workerId)
                .stream()
                .map(this::toDto)
                .toList();
    }

    public WorkOrderMediaContext getWorkOrderMediaContext(Long workOrderId, String currentUserEmail) {
        WorkOrder workOrder = workOrderRepository.findById(workOrderId)
                .orElseThrow(() -> new EntityNotFoundException("Parte no encontrado"));

        Worker current = requireWorkerByEmail(currentUserEmail);
        if (!isAdmin(current) && !isAssignedToWorkOrder(current, workOrder)) {
            throw new AccessDeniedException("No puedes subir firma a este parte");
        }

        LocalDate workOrderDate = java.time.LocalDateTime
                .ofInstant(workOrder.getCreatedAt(), java.time.ZoneId.systemDefault())
                .toLocalDate();

        return new WorkOrderMediaContext(
                workOrder.getOwner().getDisplayName(),
                workOrder.getVessel() != null ? workOrder.getVessel().getName() : null,
                workOrderDate
        );
    }

    public WorkOrderMediaContext getSigningMediaContext(Long workOrderId, String currentUserEmail) {
        return getWorkOrderMediaContext(workOrderId, currentUserEmail);
    }

    public Long findWorkerIdByEmail(String email) {
        return workerRepository.findByEmailIgnoreCase(email)
                .orElseThrow(() -> new EntityNotFoundException("Usuario no encontrado"))
                .getId();
    }

    public boolean isAdminByEmail(String email) {
        Worker worker = workerRepository.findByEmailIgnoreCase(email)
                .orElseThrow(() -> new EntityNotFoundException("Usuario no encontrado"));
        return isAdmin(worker);
    }

    @Transactional
    public WorkOrderDto create(CreateWorkOrderRequest request) {
        Owner owner = ownerRepository.findById(request.ownerId())
                .orElseThrow(() -> new EntityNotFoundException("Propietario no encontrado"));

        Vessel vessel = null;
        if (request.vesselId() != null) {
            vessel = vesselRepository.findById(request.vesselId())
                    .orElseThrow(() -> new EntityNotFoundException("Embarcacion no encontrada"));
        }

        WorkOrder workOrder = new WorkOrder();
        workOrder.setTitle(inputSanitizer.requiredText(request.title(), "El titulo", 255));
        workOrder.setDescription(inputSanitizer.optionalText(request.description(), 3000));
        workOrder.setOwner(owner);
        workOrder.setVessel(vessel);
        workOrder.setPriority(request.priority() == null ? WorkOrderPriority.NORMAL : request.priority());

        if (request.workerIds() != null && !request.workerIds().isEmpty()) {
            Set<Worker> workers = new HashSet<>(workerRepository.findAllById(request.workerIds()));
            workOrder.setAssignedWorkers(workers);
        }

        if (request.engineHours() != null) {
            for (EngineHourRequest engineReq : request.engineHours()) {
                EngineHourLog log = new EngineHourLog();
                log.setWorkOrder(workOrder);
                log.setEngineLabel(inputSanitizer.requiredText(engineReq.engineLabel(), "La etiqueta de motor", 255));
                log.setHours(engineReq.hours());
                workOrder.getEngineHourLogs().add(log);
            }
        }

        if (request.attachments() != null) {
            for (AttachmentRequest item : request.attachments()) {
                WorkOrderAttachment att = mapAttachmentRequest(workOrder, item);
                workOrder.getAttachments().add(att);
            }
        } else if (request.attachmentUrls() != null) {
            for (String url : request.attachmentUrls()) {
                WorkOrderAttachment att = new WorkOrderAttachment();
                att.setWorkOrder(workOrder);
                att.setFileUrl(inputSanitizer.optionalUrl(url, 2000));
                att.setFileType(inferType(url));
                workOrder.getAttachments().add(att);
            }
        }

        WorkOrder saved = workOrderRepository.save(workOrder);

        for (Worker worker : saved.getAssignedWorkers()) {
            notificationService.notifyWorker(
                    worker.getId(),
                    "Nuevo parte asignado",
                    "Se te ha asignado el parte: " + saved.getTitle(),
                    "PARTES",
                    saved.getPriority() == WorkOrderPriority.URGENT ? NotificationType.WARNING : NotificationType.INFO
            );
        }

        return toDto(saved);
    }

    @Transactional
    public WorkOrderDto updateStatus(Long id, UpdateWorkOrderStatusRequest request, String currentUserEmail) {
        WorkOrder workOrder = workOrderRepository.findById(id)
                .orElseThrow(() -> new EntityNotFoundException("Parte no encontrado"));

        Worker current = requireWorkerByEmail(currentUserEmail);
        if (!isAdmin(current) && !isAssignedToWorkOrder(current, workOrder)) {
            throw new AccessDeniedException("No puedes actualizar el estado de este parte");
        }

        workOrder.setStatus(request.status());
        return toDto(workOrderRepository.save(workOrder));
    }

    @Transactional
    public WorkOrderDto updateWorkOrder(Long id, UpdateWorkOrderRequest request, String currentUserEmail) {
        WorkOrder workOrder = workOrderRepository.findById(id)
                .orElseThrow(() -> new EntityNotFoundException("Parte no encontrado"));
        Set<Long> previousWorkerIds = workOrder.getAssignedWorkers().stream().map(Worker::getId).collect(java.util.stream.Collectors.toSet());

        Worker current = requireWorkerByEmail(currentUserEmail);
        boolean admin = isAdmin(current);
        boolean assigned = isAssignedToWorkOrder(current, workOrder);
        if (!admin && !assigned) {
            throw new AccessDeniedException("No tienes permiso para editar este parte");
        }

        boolean canAdvancedEdit = hasAdvancedEditPermission(current, workOrder);

        if (!canAdvancedEdit && requestHasAdvancedChanges(request)) {
            throw new AccessDeniedException(
                    "Solo administradores o mecanicos con permiso de edicion pueden editar esos campos"
            );
        }

        if (request.title() != null && !request.title().isBlank()) {
            workOrder.setTitle(inputSanitizer.requiredText(request.title(), "El titulo", 255));
        }
        if (request.description() != null) {
            workOrder.setDescription(inputSanitizer.optionalText(request.description(), 3000));
        }
        if (request.priority() != null) {
            workOrder.setPriority(request.priority());
        }
        if (request.status() != null) {
            workOrder.setStatus(request.status());
        }

        if (Boolean.TRUE.equals(request.clearSignature())) {
            if (!canAdvancedEdit) {
                throw new AccessDeniedException("No tienes permiso para borrar la firma de este parte");
            }
            if (workOrder.getSignatureUrl() != null && !workOrder.getSignatureUrl().isBlank()) {
                workOrderMediaService.deleteByPublicUrl(workOrder.getSignatureUrl());
            }
            workOrder.setSignatureUrl(null);
            workOrder.setSignedAt(null);
            workOrder.setSignedByWorker(null);
        }

        if (request.ownerId() != null) {
            Owner owner = ownerRepository.findById(request.ownerId())
                    .orElseThrow(() -> new EntityNotFoundException("Propietario no encontrado"));
            workOrder.setOwner(owner);
        }

        if (request.vesselId() != null) {
            Vessel vessel = vesselRepository.findById(request.vesselId())
                    .orElseThrow(() -> new EntityNotFoundException("Embarcacion no encontrada"));
            workOrder.setVessel(vessel);
        }

        if (request.workerIds() != null) {
            Set<Worker> workers = new HashSet<>(workerRepository.findAllById(request.workerIds()));
            workOrder.setAssignedWorkers(workers);
        }

        if (request.engineHours() != null) {
            workOrder.getEngineHourLogs().clear();
            for (EngineHourRequest engineReq : request.engineHours()) {
                EngineHourLog log = new EngineHourLog();
                log.setWorkOrder(workOrder);
                log.setEngineLabel(inputSanitizer.requiredText(engineReq.engineLabel(), "La etiqueta de motor", 255));
                log.setHours(engineReq.hours());
                workOrder.getEngineHourLogs().add(log);
            }
        }

        if (request.attachmentUrls() != null) {
            if (!canModifyMultimedia(current, workOrder)) {
                throw new AccessDeniedException("No puedes modificar multimedia de un parte firmado");
            }
            workOrder.getAttachments().clear();
            for (String url : request.attachmentUrls()) {
                WorkOrderAttachment att = new WorkOrderAttachment();
                att.setWorkOrder(workOrder);
                att.setFileUrl(inputSanitizer.optionalUrl(url, 2000));
                att.setFileType(inferType(url));
                workOrder.getAttachments().add(att);
            }
        }

        if (request.attachments() != null) {
            if (!canModifyMultimedia(current, workOrder)) {
                throw new AccessDeniedException("No puedes modificar multimedia de un parte firmado");
            }
            workOrder.getAttachments().clear();
            for (AttachmentRequest item : request.attachments()) {
                WorkOrderAttachment att = mapAttachmentRequest(workOrder, item);
                workOrder.getAttachments().add(att);
            }
        }

        WorkOrder saved = workOrderRepository.save(workOrder);
        Set<Long> updatedWorkerIds = saved.getAssignedWorkers().stream().map(Worker::getId).collect(java.util.stream.Collectors.toSet());

        for (Long workerId : updatedWorkerIds) {
            if (!previousWorkerIds.contains(workerId)) {
                notificationService.notifyWorker(
                        workerId,
                        "Nuevo parte asignado",
                        "Se te ha asignado el parte: " + saved.getTitle(),
                        "PARTES",
                        saved.getPriority() == WorkOrderPriority.URGENT ? NotificationType.WARNING : NotificationType.INFO
                );
            }
        }

        return toDto(saved);
    }

    @Transactional
    public WorkOrderDto deleteAttachment(Long workOrderId, Long attachmentId, String currentUserEmail) {
        WorkOrder workOrder = workOrderRepository.findById(workOrderId)
                .orElseThrow(() -> new EntityNotFoundException("Parte no encontrado"));

        Worker current = requireWorkerByEmail(currentUserEmail);
        if (!canDeleteAttachment(current, workOrder)) {
            throw new AccessDeniedException("No tienes permiso para borrar multimedia de este parte");
        }

        WorkOrderAttachment attachment = workOrder.getAttachments().stream()
                .filter(item -> item.getId().equals(attachmentId))
                .findFirst()
                .orElseThrow(() -> new EntityNotFoundException("Adjunto no encontrado en este parte"));

        workOrder.getAttachments().remove(attachment);
        workOrderMediaService.deleteByPublicUrl(attachment.getFileUrl());

        return toDto(workOrderRepository.save(workOrder));
    }

    @Transactional
    public WorkOrderDto addAttachment(Long workOrderId,
                                      UploadedAttachmentDto attachment,
                                      String currentUserEmail) {
        WorkOrder workOrder = workOrderRepository.findById(workOrderId)
                .orElseThrow(() -> new EntityNotFoundException("Parte no encontrado"));

        Worker current = requireWorkerByEmail(currentUserEmail);
        if (!canModifyMultimedia(current, workOrder)) {
            throw new AccessDeniedException("No puedes modificar multimedia de este parte");
        }

        WorkOrderAttachment att = new WorkOrderAttachment();
        att.setWorkOrder(workOrder);
        att.setFileUrl(attachment.fileUrl());
        att.setFileType(attachment.fileType());
        att.setOriginalFileName(attachment.originalFileName());
        att.setCapturedAt(attachment.capturedAt());
        att.setLatitude(attachment.latitude());
        att.setLongitude(attachment.longitude());
        att.setWatermarked(attachment.watermarked());
        att.setAudioRemoved(attachment.audioRemoved());
        workOrder.getAttachments().add(att);

        return toDto(workOrderRepository.save(workOrder));
    }

    @Transactional
    public void deleteWorkOrder(Long workOrderId, String currentUserEmail) {
        WorkOrder workOrder = workOrderRepository.findById(workOrderId)
                .orElseThrow(() -> new EntityNotFoundException("Parte no encontrado"));

        Worker current = requireWorkerByEmail(currentUserEmail);
        if (!isAdmin(current)) {
            throw new AccessDeniedException("Solo un administrador puede borrar partes");
        }

        List<String> mediaUrls = new ArrayList<>();
        if (workOrder.getSignatureUrl() != null && !workOrder.getSignatureUrl().isBlank()) {
            mediaUrls.add(workOrder.getSignatureUrl());
        }
        for (WorkOrderAttachment att : workOrder.getAttachments()) {
            mediaUrls.add(att.getFileUrl());
        }

        workOrder.getAssignedWorkers().clear();
        workOrderRepository.delete(workOrder);

        for (String mediaUrl : mediaUrls) {
            workOrderMediaService.deleteByPublicUrl(mediaUrl);
        }
    }

    private Worker requireWorkerByEmail(String email) {
        return workerRepository.findByEmailIgnoreCase(email)
                .orElseThrow(() -> new EntityNotFoundException("Usuario no encontrado"));
    }

    private boolean isAdmin(Worker worker) {
        return worker.getRole() == com.navalgo.backend.common.Role.ADMIN;
    }

    private boolean canEditWorkOrder(Worker worker, WorkOrder workOrder) {
        return isAdmin(worker) || (isAssignedToWorkOrder(worker, workOrder) && worker.isCanEditWorkOrders());
    }

    private boolean hasAdvancedEditPermission(Worker worker, WorkOrder workOrder) {
        return isAdmin(worker) || (isAssignedToWorkOrder(worker, workOrder) && worker.isCanEditWorkOrders());
    }

    private boolean requestHasAdvancedChanges(UpdateWorkOrderRequest request) {
        return (request.title() != null && !request.title().isBlank())
                || request.priority() != null
                || request.status() != null
                || request.ownerId() != null
                || request.vesselId() != null
                || request.workerIds() != null
                || Boolean.TRUE.equals(request.clearSignature());
    }

    private boolean canModifyMultimedia(Worker worker, WorkOrder workOrder) {
        if (isAdmin(worker)) {
            return true;
        }
        if (isAssignedToWorkOrder(worker, workOrder) && worker.isCanEditWorkOrders()) {
            return true;
        }
        return !isSigned(workOrder);
    }

    private boolean canDeleteAttachment(Worker worker, WorkOrder workOrder) {
        if (isAdmin(worker)) {
            return true;
        }
        if (isAssignedToWorkOrder(worker, workOrder) && worker.isCanEditWorkOrders()) {
            return true;
        }
        // Workers without edit permission can only remove media while work order is unsigned.
        return isAssignedToWorkOrder(worker, workOrder) && !isSigned(workOrder);
    }

    private boolean isSigned(WorkOrder workOrder) {
        return (workOrder.getSignatureUrl() != null && !workOrder.getSignatureUrl().isBlank())
                || workOrder.getSignedAt() != null;
    }

    private boolean isAssignedToWorkOrder(Worker worker, WorkOrder workOrder) {
        return workOrder.getAssignedWorkers().stream().anyMatch(w -> w.getId().equals(worker.getId()));
    }

    private WorkOrderDto toDto(WorkOrder w) {
        Owner owner = w.getOwner();
        Vessel vessel = w.getVessel();

        Set<Worker> assignedWorkers = w.getAssignedWorkers() == null
            ? Collections.emptySet()
            : w.getAssignedWorkers();

        List<Long> workerIds = assignedWorkers.stream()
            .map(Worker::getId)
            .filter(Objects::nonNull)
            .toList();

        List<String> workerNames = assignedWorkers.stream()
            .map(Worker::getFullName)
            .filter(Objects::nonNull)
            .toList();

        List<EngineHourRequest> engineHours = w.getEngineHourLogs() == null
            ? List.of()
            : w.getEngineHourLogs().stream()
                .map(e -> new EngineHourRequest(e.getEngineLabel(), e.getHours()))
                .toList();

        Set<WorkOrderAttachment> attachments = w.getAttachments() == null
            ? Set.of()
            : w.getAttachments();

        return new WorkOrderDto(
                w.getId(),
                w.getTitle(),
                w.getDescription(),
                w.getStatus(),
                w.getPriority(),
            owner != null ? owner.getId() : null,
            owner != null ? owner.getDisplayName() : "Sin propietario",
            vessel != null ? vessel.getId() : null,
            vessel != null ? vessel.getName() : null,
            workerIds,
            workerNames,
            engineHours,
            attachments.stream().map(WorkOrderAttachment::getFileUrl).filter(Objects::nonNull).toList(),
            attachments.stream().map(AttachmentInfoDto::from).toList(),
                w.getCreatedAt(),
                w.getSignatureUrl(),
                w.getSignedAt(),
                w.getSignedByWorker() != null ? w.getSignedByWorker().getId() : null,
                w.getSignedByWorker() != null ? w.getSignedByWorker().getFullName() : null
        );
    }

    @Transactional
    public WorkOrderDto signWorkOrder(Long id,
                                      UploadedAttachmentDto signature,
                                      List<UploadedAttachmentDto> proofAttachments,
                                      String signerEmail) {
        WorkOrder workOrder = workOrderRepository.findById(id)
                .orElseThrow(() -> new EntityNotFoundException("Parte no encontrado"));

        Worker signer = requireWorkerByEmail(signerEmail);
        if (!isAdmin(signer) && !isAssignedToWorkOrder(signer, workOrder)) {
            throw new AccessDeniedException("Solo puedes firmar partes que tienes asignados");
        }

        workOrder.setSignatureUrl(signature.fileUrl());
        workOrder.setSignedAt(java.time.Instant.now());
        workOrder.setSignedByWorker(signer);

        for (UploadedAttachmentDto proof : proofAttachments) {
            WorkOrderAttachment att = new WorkOrderAttachment();
            att.setWorkOrder(workOrder);
            att.setFileUrl(proof.fileUrl());
            att.setFileType(proof.fileType());
            att.setOriginalFileName(proof.originalFileName());
            att.setCapturedAt(proof.capturedAt());
            att.setLatitude(proof.latitude());
            att.setLongitude(proof.longitude());
            att.setWatermarked(proof.watermarked());
            att.setAudioRemoved(proof.audioRemoved());
            workOrder.getAttachments().add(att);
        }

        return toDto(workOrderRepository.save(workOrder));
    }

    private WorkOrderAttachment mapAttachmentRequest(WorkOrder workOrder, AttachmentRequest item) {
        WorkOrderAttachment att = new WorkOrderAttachment();
        att.setWorkOrder(workOrder);
        att.setFileUrl(inputSanitizer.optionalUrl(item.fileUrl(), 2000));
        att.setFileType(inputSanitizer.requiredText(item.fileType(), "El tipo de archivo", 255));
        att.setOriginalFileName(inputSanitizer.optionalText(item.originalFileName(), 255));
        att.setCapturedAt(item.capturedAt());
        att.setLatitude(item.latitude());
        att.setLongitude(item.longitude());
        att.setWatermarked(item.watermarked());
        att.setAudioRemoved(item.audioRemoved());
        return att;
    }

    private String inferType(String fileUrl) {
        String normalized = fileUrl.toLowerCase(Locale.ROOT);
        if (normalized.endsWith(".mp4") || normalized.endsWith(".mov") || normalized.endsWith(".avi")) {
            return "VIDEO";
        }
        return "IMAGE";
    }

    public record WorkOrderMediaContext(
            String ownerName,
            String vesselName,
            LocalDate workOrderDate
    ) {
    }
}
