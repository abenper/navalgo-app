package com.navalgo.backend.workorder;

import com.navalgo.backend.common.InputSanitizer;
import com.navalgo.backend.common.Role;
import com.navalgo.backend.fleet.Owner;
import com.navalgo.backend.fleet.OwnerRepository;
import com.navalgo.backend.fleet.Vessel;
import com.navalgo.backend.fleet.VesselRepository;
import com.navalgo.backend.notification.NotificationService;
import com.navalgo.backend.notification.NotificationType;
import com.navalgo.backend.notification.NotificationDeliveryOptions;
import com.navalgo.backend.worker.Worker;
import com.navalgo.backend.worker.WorkerRepository;
import org.springframework.security.access.AccessDeniedException;
import jakarta.persistence.EntityNotFoundException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.time.LocalDate;
import java.util.*;

@Service
@Transactional(readOnly = true)
public class WorkOrderService {
    private static final String SUPERADMIN_EMAIL = "admin@naval-go.com";

    private final WorkOrderRepository workOrderRepository;
    private final OwnerRepository ownerRepository;
    private final VesselRepository vesselRepository;
    private final WorkerRepository workerRepository;
    private final NotificationService notificationService;
    private final WorkOrderMediaService workOrderMediaService;
    private final WorkOrderEvidenceService workOrderEvidenceService;
    private final WorkOrderEvidencePdfService workOrderEvidencePdfService;
    private final MaterialChecklistTemplateRepository materialChecklistTemplateRepository;
    private final InputSanitizer inputSanitizer;

    public WorkOrderService(WorkOrderRepository workOrderRepository,
                            OwnerRepository ownerRepository,
                            VesselRepository vesselRepository,
                            WorkerRepository workerRepository,
                            NotificationService notificationService,
                            WorkOrderMediaService workOrderMediaService,
                            WorkOrderEvidenceService workOrderEvidenceService,
                            WorkOrderEvidencePdfService workOrderEvidencePdfService,
                            MaterialChecklistTemplateRepository materialChecklistTemplateRepository,
                            InputSanitizer inputSanitizer) {
        this.workOrderRepository = workOrderRepository;
        this.ownerRepository = ownerRepository;
        this.vesselRepository = vesselRepository;
        this.workerRepository = workerRepository;
        this.notificationService = notificationService;
        this.workOrderMediaService = workOrderMediaService;
        this.workOrderEvidenceService = workOrderEvidenceService;
        this.workOrderEvidencePdfService = workOrderEvidencePdfService;
        this.materialChecklistTemplateRepository = materialChecklistTemplateRepository;
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

    public WorkOrderDto findById(Long id, String currentUserEmail) {
        WorkOrder workOrder = workOrderRepository.findById(id)
                .orElseThrow(() -> new EntityNotFoundException("Parte no encontrado"));

        Worker current = requireWorkerByEmail(currentUserEmail);
        if (!isAdmin(current) && !isAssignedToWorkOrder(current, workOrder)) {
            throw new AccessDeniedException("Solo puedes ver tus propios partes");
        }

        return toDto(workOrder);
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
    public WorkOrderDto create(CreateWorkOrderRequest request, String currentUserEmail) {
        Worker current = requireWorkerByEmail(currentUserEmail);
        Vessel vessel = null;
        if (request.vesselId() != null) {
            vessel = vesselRepository.findByIdAndArchivedFalse(request.vesselId())
                    .orElseThrow(() -> new EntityNotFoundException("Embarcacion no encontrada"));
        }
        if (vessel == null) {
            throw new IllegalArgumentException("Selecciona una embarcacion para crear el parte");
        }

        Owner owner = vessel.getOwner();

        WorkOrder workOrder = new WorkOrder();
        workOrder.setTitle(resolveCreateTitle(request.title(), vessel, request.description()));
        workOrder.setDescription(inputSanitizer.optionalText(request.description(), 3000));
        workOrder.setOwner(owner);
        workOrder.setVessel(vessel);
        workOrder.setPriority(request.priority() == null ? WorkOrderPriority.NORMAL : request.priority());
        workOrder.setCloseDueDate(request.closeDueDate() == null ? java.time.LocalDate.now().plusDays(1) : request.closeDueDate());
        workOrder.setLaborHours(request.laborHours());

        if (request.materialTemplateId() != null) {
            MaterialChecklistTemplate template = materialChecklistTemplateRepository.findById(request.materialTemplateId())
                .orElseThrow(() -> new EntityNotFoundException("Plantilla de material no encontrada"));
            applyMaterialChecklistTemplate(workOrder, template);
            workOrder.setDescription(mergeAutoMaterialObservations(workOrder.getDescription(), workOrder.getMaterialChecklist()));
        }

        if (request.workerIds() != null && !request.workerIds().isEmpty()) {
            if (!isAdmin(current)) {
                throw new AccessDeniedException("Solo un administrador puede asignar trabajadores al crear partes");
            }
            Set<Worker> workers = resolveAssignableWorkers(request.workerIds());
            workOrder.setAssignedWorkers(workers);
        } else if (!isAdmin(current)) {
            workOrder.setAssignedWorkers(new HashSet<>(Set.of(current)));
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
                WorkOrderAttachment att = mapAttachmentRequest(workOrder, item, current);
                workOrder.getAttachments().add(att);
            }
        } else if (request.attachmentUrls() != null) {
            for (String url : request.attachmentUrls()) {
                WorkOrderAttachment att = mapLegacyAttachmentUrl(workOrder, url, current);
                workOrder.getAttachments().add(att);
            }
        }

        WorkOrder saved = workOrderRepository.saveAndFlush(workOrder);
        signAllAttachmentEvidence(saved);
        saved = workOrderRepository.save(saved);

        for (Worker worker : saved.getAssignedWorkers()) {
            notificationService.notifyWorker(
                    worker.getId(),
                    "Nuevo parte asignado",
                    buildAssignmentMessage(saved),
                    "PARTES",
                    saved.getPriority() == WorkOrderPriority.URGENT ? NotificationType.WARNING : NotificationType.INFO,
                    NotificationDeliveryOptions.EMAIL_FALLBACK
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
        ensureNotSealed(workOrder);

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
        ensureNotSealed(workOrder);

        boolean canEditUnsignedWorkOrder = canEditWorkOrder(current, workOrder);

        if (request.title() != null && !request.title().isBlank()) {
            workOrder.setTitle(inputSanitizer.requiredText(request.title(), "El titulo", 255));
        }
        if (request.description() != null) {
            String sanitizedDescription = inputSanitizer.optionalText(request.description(), 3000);
            workOrder.setDescription(
                    mergeAutoMaterialObservations(sanitizedDescription, workOrder.getMaterialChecklist())
            );
        }
        if (request.priority() != null) {
            workOrder.setPriority(request.priority());
        }
        if (request.closeDueDate() != null) {
            workOrder.setCloseDueDate(request.closeDueDate());
        }
        if (request.laborHours() != null) {
            workOrder.setLaborHours(request.laborHours());
        }
        if (request.status() != null) {
            workOrder.setStatus(request.status());
        }

        if (Boolean.TRUE.equals(request.clearSignature())) {
            if (!canEditUnsignedWorkOrder) {
                throw new AccessDeniedException("No tienes permiso para borrar la firma de este parte");
            }
            if (workOrder.getSignatureUrl() != null && !workOrder.getSignatureUrl().isBlank()) {
                workOrderMediaService.deleteByPublicUrl(workOrder.getSignatureUrl());
            }
            workOrder.setSignatureUrl(null);
            workOrder.setSignedAt(null);
            workOrder.setSignedByWorker(null);
        }

        if (Boolean.TRUE.equals(request.clearClientSignature())) {
            if (!canEditUnsignedWorkOrder) {
                throw new AccessDeniedException("No tienes permiso para borrar la firma de cliente de este parte");
            }
            if (workOrder.getClientSignatureUrl() != null && !workOrder.getClientSignatureUrl().isBlank()) {
                workOrderMediaService.deleteByPublicUrl(workOrder.getClientSignatureUrl());
            }
            workOrder.setClientSignatureUrl(null);
            workOrder.setClientSignedAt(null);
        }

        if (request.materialTemplateId() != null) {
            MaterialChecklistTemplate template = materialChecklistTemplateRepository.findById(request.materialTemplateId())
                    .orElseThrow(() -> new EntityNotFoundException("Plantilla de material no encontrada"));
            applyMaterialChecklistTemplate(workOrder, template);
            workOrder.setDescription(mergeAutoMaterialObservations(workOrder.getDescription(), workOrder.getMaterialChecklist()));
        }

        if (Boolean.TRUE.equals(request.clearMaterialChecklist())) {
            workOrder.setMaterialChecklist(null);
            workOrder.setDescription(mergeAutoMaterialObservations(workOrder.getDescription(), null));
        }

        if (request.ownerId() != null) {
            Owner owner = ownerRepository.findByIdAndArchivedFalse(request.ownerId())
                    .orElseThrow(() -> new EntityNotFoundException("Propietario no encontrado"));
            workOrder.setOwner(owner);
        }

        if (request.vesselId() != null) {
            Vessel vessel = vesselRepository.findByIdAndArchivedFalse(request.vesselId())
                    .orElseThrow(() -> new EntityNotFoundException("Embarcacion no encontrada"));
            workOrder.setVessel(vessel);
        }

        if (request.workerIds() != null) {
            Set<Worker> workers = resolveAssignableWorkers(request.workerIds());
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
                WorkOrderAttachment att = mapLegacyAttachmentUrl(workOrder, url, current);
                workOrder.getAttachments().add(att);
            }
        }

        if (request.attachments() != null) {
            if (!canModifyMultimedia(current, workOrder)) {
                throw new AccessDeniedException("No puedes modificar multimedia de un parte firmado");
            }
            workOrder.getAttachments().clear();
            for (AttachmentRequest item : request.attachments()) {
                WorkOrderAttachment att = mapAttachmentRequest(workOrder, item, current);
                workOrder.getAttachments().add(att);
            }
        }

        WorkOrder saved = workOrderRepository.saveAndFlush(workOrder);
        signAllAttachmentEvidence(saved);
        saved = workOrderRepository.save(saved);
        Set<Long> updatedWorkerIds = saved.getAssignedWorkers().stream().map(Worker::getId).collect(java.util.stream.Collectors.toSet());

        for (Long workerId : updatedWorkerIds) {
            if (!previousWorkerIds.contains(workerId)) {
                notificationService.notifyWorker(
                        workerId,
                        "Nuevo parte asignado",
                    buildAssignmentMessage(saved),
                        "PARTES",
                        saved.getPriority() == WorkOrderPriority.URGENT ? NotificationType.WARNING : NotificationType.INFO,
                        NotificationDeliveryOptions.EMAIL_FALLBACK
                );
            }
        }

        if (!admin) {
            notificationService.notifyAdmins(
                    "Parte actualizado por trabajador",
                    current.getFullName() + " ha actualizado el parte \"" + saved.getTitle() + "\".",
                    "PARTES",
                    NotificationType.INFO
            );
        }

        return toDto(saved);
    }

    @Transactional
    public WorkOrderDto updateMaterialChecklist(Long id,
                                                UpdateWorkOrderChecklistRequest request,
                                                String currentUserEmail) {
        WorkOrder workOrder = workOrderRepository.findById(id)
                .orElseThrow(() -> new EntityNotFoundException("Parte no encontrado"));

        Worker current = requireWorkerByEmail(currentUserEmail);
        if (!isAdmin(current) && !isAssignedToWorkOrder(current, workOrder)) {
            throw new AccessDeniedException("No puedes revisar material en este parte");
        }
        ensureNotSealed(workOrder);

        WorkOrderChecklist checklist = requireMaterialChecklist(workOrder);
        Map<Long, WorkOrderChecklistItem> itemsById = new HashMap<>();
        for (WorkOrderChecklistItem item : checklist.getItems()) {
            itemsById.put(item.getId(), item);
        }

        for (WorkOrderChecklistItemUpdateRequest itemRequest : request.items()) {
            WorkOrderChecklistItem item = itemsById.get(itemRequest.itemId());
            if (item == null) {
                throw new EntityNotFoundException("Elemento de checklist no encontrado en este parte");
            }

            boolean checked = Boolean.TRUE.equals(itemRequest.checked());
            item.setChecked(checked);
            item.setCheckedAt(checked ? Instant.now() : null);
            item.setCheckedByWorker(checked ? current : null);
        }

        return toDto(workOrderRepository.save(workOrder));
    }

    @Transactional
    public WorkOrderDto createMaterialRevisionRequest(Long id,
                                                      CreateMaterialRevisionRequest request,
                                                      String currentUserEmail) {
        WorkOrder workOrder = workOrderRepository.findById(id)
                .orElseThrow(() -> new EntityNotFoundException("Parte no encontrado"));

        Worker current = requireWorkerByEmail(currentUserEmail);
        if (!isAdmin(current) && !isAssignedToWorkOrder(current, workOrder)) {
            throw new AccessDeniedException("No puedes crear incidencias de material en este parte");
        }
        ensureNotSealed(workOrder);

        WorkOrderChecklist checklist = requireMaterialChecklist(workOrder);
        WorkOrderChecklistItem checklistItem = checklist.getItems().stream()
                .filter(item -> item.getId().equals(request.checklistItemId()))
                .findFirst()
                .orElseThrow(() -> new EntityNotFoundException("Articulo no encontrado en este checklist"));

        MaterialRevisionRequest revisionRequest = new MaterialRevisionRequest();
        revisionRequest.setWorkOrder(workOrder);
        revisionRequest.setChecklistItemSnapshotId(checklistItem.getId());
        revisionRequest.setSourceTemplateId(checklist.getSourceTemplateId());
        revisionRequest.setSourceTemplateItemId(checklistItem.getSourceTemplateItemId());
        revisionRequest.setProductId(checklistItem.getProductId());
        revisionRequest.setArticleName(checklistItem.getArticleName());
        revisionRequest.setReference(checklistItem.getReference());
        revisionRequest.setObservations(
                inputSanitizer.requiredText(request.observations(), "Las observaciones", 3000)
        );
        revisionRequest.setStatus(MaterialRevisionRequestStatus.PENDING);
        revisionRequest.setRequestedByWorker(current);
        revisionRequest.setCreatedAt(Instant.now());

        workOrder.getMaterialRevisionRequests().add(revisionRequest);
        WorkOrder saved = workOrderRepository.save(workOrder);
        String materialLabel = checklistItem.getArticleName() != null && !checklistItem.getArticleName().isBlank()
                ? checklistItem.getArticleName()
                : checklistItem.getReference();

        notificationService.notifyAdmins(
                "Solicitud de cambio de material",
                current.getFullName()
                        + " ha solicitado revisar material en el parte \""
                        + workOrder.getTitle()
                        + "\": "
                        + materialLabel
                        + ".",
                "PARTES",
                NotificationType.WARNING
        );

        return toDto(saved);
    }

    @Transactional
    public WorkOrderDto updateMaterialRevisionRequestStatus(Long workOrderId,
                                                            Long requestId,
                                                            UpdateMaterialRevisionRequestStatusRequest request,
                                                            String currentUserEmail) {
        WorkOrder workOrder = workOrderRepository.findById(workOrderId)
                .orElseThrow(() -> new EntityNotFoundException("Parte no encontrado"));

        Worker current = requireWorkerByEmail(currentUserEmail);
        if (!isAdmin(current)) {
            throw new AccessDeniedException("Solo un administrador puede revisar incidencias de material");
        }
        ensureNotSealed(workOrder);

        MaterialRevisionRequest revisionRequest = workOrder.getMaterialRevisionRequests().stream()
                .filter(item -> item.getId().equals(requestId))
                .findFirst()
                .orElseThrow(() -> new EntityNotFoundException("Solicitud de revision no encontrada"));

        revisionRequest.setStatus(request.status());
        revisionRequest.setResolutionNote(inputSanitizer.optionalText(request.resolutionNote(), 1000));
        if (request.status() == MaterialRevisionRequestStatus.PENDING) {
            revisionRequest.setReviewedAt(null);
            revisionRequest.setReviewedByWorker(null);
        } else {
            revisionRequest.setReviewedAt(Instant.now());
            revisionRequest.setReviewedByWorker(current);
        }

        return toDto(workOrderRepository.save(workOrder));
    }

    @Transactional
    public WorkOrderDto deleteAttachment(Long workOrderId, Long attachmentId, String currentUserEmail) {
        WorkOrder workOrder = workOrderRepository.findById(workOrderId)
                .orElseThrow(() -> new EntityNotFoundException("Parte no encontrado"));

        Worker current = requireWorkerByEmail(currentUserEmail);
        if (!canDeleteAttachment(current, workOrder)) {
            throw new AccessDeniedException("No tienes permiso para borrar multimedia de este parte");
        }
        ensureNotSealed(workOrder);

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
                                      String currentUserEmail,
                                      String uploadIp,
                                      String uploadUserAgent) {
        WorkOrder workOrder = workOrderRepository.findById(workOrderId)
                .orElseThrow(() -> new EntityNotFoundException("Parte no encontrado"));

        Worker current = requireWorkerByEmail(currentUserEmail);
        if (!canModifyMultimedia(current, workOrder)) {
            throw new AccessDeniedException("No puedes modificar multimedia de este parte");
        }
        ensureNotSealed(workOrder);

        WorkOrderAttachment att = buildAttachmentEntity(workOrder, attachment, current, uploadIp, uploadUserAgent);
        workOrder.getAttachments().add(att);
        WorkOrder saved = workOrderRepository.saveAndFlush(workOrder);
        signAttachmentEvidence(saved, att);
        return toDto(workOrderRepository.save(saved));
    }

    @Transactional
    public void deleteWorkOrder(Long workOrderId, String currentUserEmail) {
        WorkOrder workOrder = workOrderRepository.findById(workOrderId)
                .orElseThrow(() -> new EntityNotFoundException("Parte no encontrado"));

        Worker current = requireWorkerByEmail(currentUserEmail);
        if (!isAdmin(current)) {
            throw new AccessDeniedException("Solo un administrador puede borrar partes");
        }
        if (isSealed(workOrder) && !isSuperAdmin(current)) {
            throw new AccessDeniedException("No se puede borrar un parte sellado");
        }

        Set<String> mediaUrls = new LinkedHashSet<>();
        Set<String> storageObjectKeys = new LinkedHashSet<>();
        if (workOrder.getSignatureUrl() != null && !workOrder.getSignatureUrl().isBlank()) {
            mediaUrls.add(workOrder.getSignatureUrl());
        }
        if (workOrder.getClientSignatureUrl() != null && !workOrder.getClientSignatureUrl().isBlank()) {
            mediaUrls.add(workOrder.getClientSignatureUrl());
        }
        for (WorkOrderAttachment att : workOrder.getAttachments()) {
            if (att.getStorageObjectKey() != null && !att.getStorageObjectKey().isBlank()) {
                storageObjectKeys.add(att.getStorageObjectKey());
            } else {
                mediaUrls.add(att.getFileUrl());
            }
        }

        workOrder.getAssignedWorkers().clear();
        workOrderRepository.delete(workOrder);

        for (String storageObjectKey : storageObjectKeys) {
            workOrderMediaService.deleteByObjectKey(storageObjectKey);
        }
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

    private boolean isSuperAdmin(Worker worker) {
        return worker != null
                && worker.getEmail() != null
                && SUPERADMIN_EMAIL.equalsIgnoreCase(worker.getEmail().trim());
    }

    private Set<Worker> resolveAssignableWorkers(List<Long> workerIds) {
        Set<Long> requestedWorkerIds = new HashSet<>(workerIds);
        Set<Worker> workers = new HashSet<>(workerRepository.findAllById(requestedWorkerIds));
        if (workers.size() != requestedWorkerIds.size()) {
            throw new EntityNotFoundException("Uno o varios trabajadores asignados no existen");
        }

        boolean invalidRole = workers.stream().anyMatch(worker -> worker.getRole() != Role.WORKER);
        if (invalidRole) {
            throw new IllegalArgumentException("Solo se pueden asignar usuarios con rol trabajador");
        }

        boolean inactiveWorker = workers.stream().anyMatch(worker -> !worker.isActive());
        if (inactiveWorker) {
            throw new IllegalArgumentException("No se pueden asignar trabajadores inactivos");
        }

        return workers;
    }

    private boolean canEditWorkOrder(Worker worker, WorkOrder workOrder) {
        return !isSealed(workOrder) && (isAdmin(worker) || isAssignedToWorkOrder(worker, workOrder));
    }

    private boolean canModifyMultimedia(Worker worker, WorkOrder workOrder) {
        return !isSealed(workOrder)
                && (isAdmin(worker)
                || (isAssignedToWorkOrder(worker, workOrder) && worker.isCanEditWorkOrders())
                || isAssignedToWorkOrder(worker, workOrder));
    }

    private boolean canDeleteAttachment(Worker worker, WorkOrder workOrder) {
        return !isSealed(workOrder)
                && (isAdmin(worker)
                || (isAssignedToWorkOrder(worker, workOrder) && worker.isCanEditWorkOrders())
                || isAssignedToWorkOrder(worker, workOrder));
    }

    private boolean isSigned(WorkOrder workOrder) {
        return (workOrder.getSignatureUrl() != null && !workOrder.getSignatureUrl().isBlank())
                || workOrder.getSignedAt() != null;
    }

    private boolean isSealed(WorkOrder workOrder) {
        return isSigned(workOrder) || workOrder.getEvidenceSealedAt() != null;
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

        List<Long> workerIds = new java.util.ArrayList<>();
        List<String> workerNames = new java.util.ArrayList<>();
        for (Worker worker : assignedWorkers) {
            try {
                Long wid = worker.getId();
                String name = worker.getFullName();
                if (wid != null) workerIds.add(wid);
                if (name != null) workerNames.add(name);
            } catch (jakarta.persistence.EntityNotFoundException ignored) {
                // Worker was deleted but still referenced in join table — skip silently
            }
        }

        List<EngineHourRequest> engineHours = w.getEngineHourLogs() == null
            ? List.of()
            : w.getEngineHourLogs().stream()
                .map(e -> new EngineHourRequest(e.getEngineLabel(), e.getHours()))
                .toList();

        WorkOrderChecklistDto materialChecklist = w.getMaterialChecklist() == null
            ? null
            : toChecklistDto(w.getMaterialChecklist());

        List<MaterialRevisionRequestDto> materialRevisionRequests = w.getMaterialRevisionRequests() == null
            ? List.of()
            : w.getMaterialRevisionRequests().stream()
            .sorted(Comparator.comparing(MaterialRevisionRequest::getCreatedAt).reversed())
            .map(this::toMaterialRevisionRequestDto)
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
            w.getLaborHours(),
            materialChecklist,
            materialRevisionRequests,
            engineHours,
            attachments.stream().map(WorkOrderAttachment::getFileUrl).filter(Objects::nonNull).toList(),
            attachments.stream().map(AttachmentInfoDto::from).toList(),
                w.getCloseDueDate(),
                w.getCreatedAt(),
                w.getSignatureUrl(),
                w.getClientSignatureUrl(),
                w.getSignedAt(),
                w.getClientSignedAt(),
                w.getSignedByWorker() != null ? w.getSignedByWorker().getId() : null,
                w.getSignedByWorker() != null ? w.getSignedByWorker().getFullName() : null,
                w.getEvidenceSealedAt(),
                w.getEvidenceManifestHash(),
                w.getEvidenceServerSignature()
        );
    }

    private String buildAssignmentMessage(WorkOrder workOrder) {
        StringBuilder builder = new StringBuilder("Se te ha asignado el parte: ")
                .append(workOrder.getTitle());
        if (workOrder.getCloseDueDate() != null) {
            builder.append(". Cierre previsto: ")
                    .append(formatCloseDate(workOrder.getCloseDueDate()));
        }
        return builder.toString();
    }

    private String formatCloseDate(LocalDate closeDate) {
        String day = String.format("%02d", closeDate.getDayOfMonth());
        String month = String.format("%02d", closeDate.getMonthValue());
        return day + "/" + month + "/" + closeDate.getYear();
    }

    private String resolveCreateTitle(String requestedTitle, Vessel vessel, String description) {
        String sanitizedTitle = inputSanitizer.optionalText(requestedTitle, 255);
        if (sanitizedTitle != null && !sanitizedTitle.isBlank()) {
            return sanitizedTitle;
        }

        if (vessel != null && vessel.getName() != null && !vessel.getName().isBlank()) {
            return inputSanitizer.requiredText("Trabajo en " + vessel.getName(), "El titulo", 255);
        }

        String sanitizedDescription = inputSanitizer.optionalText(description, 255);
        if (sanitizedDescription != null && !sanitizedDescription.isBlank()) {
            return sanitizedDescription.length() <= 80
                    ? sanitizedDescription
                    : sanitizedDescription.substring(0, 80).trim();
        }

        return "Parte de trabajo";
    }

    @Transactional
    public WorkOrderDto signWorkOrder(Long id,
                                      UploadedAttachmentDto signature,
                                      List<UploadedAttachmentDto> proofAttachments,
                                      String signerEmail,
                                      String uploadIp,
                                      String uploadUserAgent) {
        WorkOrder workOrder = workOrderRepository.findById(id)
                .orElseThrow(() -> new EntityNotFoundException("Parte no encontrado"));

        Worker signer = requireWorkerByEmail(signerEmail);
        if (!isAdmin(signer) && !isAssignedToWorkOrder(signer, workOrder)) {
            throw new AccessDeniedException("Solo puedes firmar partes que tienes asignados");
        }
        ensureNotSealed(workOrder);

        if (workOrder.getLaborHours() == null) {
            throw new IllegalArgumentException("Rellena las horas de trabajo del parte antes de firmar y cerrar.");
        }

        workOrder.setSignatureUrl(signature.fileUrl());
        workOrder.setSignedAt(java.time.Instant.now());
        workOrder.setSignedByWorker(signer);
        workOrder.setStatus(WorkOrderStatus.DONE);

        for (UploadedAttachmentDto proof : proofAttachments) {
            WorkOrderAttachment att = buildAttachmentEntity(workOrder, proof, signer, uploadIp, uploadUserAgent);
            workOrder.getAttachments().add(att);
        }

        WorkOrder saved = workOrderRepository.saveAndFlush(workOrder);
        signAllAttachmentEvidence(saved);
        sealWorkOrderEvidence(saved);
        saved = workOrderRepository.save(saved);

        if (!isAdmin(signer)) {
            notificationService.notifyAdmins(
                    "Parte firmado por trabajador",
                    signer.getFullName() + " ha firmado y cerrado el parte \"" + saved.getTitle() + "\".",
                    "PARTES",
                    NotificationType.SUCCESS,
                    NotificationDeliveryOptions.EMAIL_FALLBACK
            );
        }

        return toDto(saved);
    }

    @Transactional
    public WorkOrderDto saveClientSignature(Long id,
                                            UploadedAttachmentDto clientSignature,
                                            String signerEmail) {
        WorkOrder workOrder = workOrderRepository.findById(id)
                .orElseThrow(() -> new EntityNotFoundException("Parte no encontrado"));

        Worker signer = requireWorkerByEmail(signerEmail);
        if (!isAdmin(signer) && !isAssignedToWorkOrder(signer, workOrder)) {
            throw new AccessDeniedException("Solo puedes registrar la firma de cliente en partes que tienes asignados");
        }
        ensureNotSealed(workOrder);

        String previousClientSignatureUrl = workOrder.getClientSignatureUrl();
        workOrder.setClientSignatureUrl(clientSignature.fileUrl());
        workOrder.setClientSignedAt(Instant.now());

        WorkOrder saved = workOrderRepository.save(workOrder);
        if (previousClientSignatureUrl != null
                && !previousClientSignatureUrl.isBlank()
                && !previousClientSignatureUrl.equals(clientSignature.fileUrl())) {
            workOrderMediaService.deleteByPublicUrl(previousClientSignatureUrl);
        }

        return toDto(saved);
    }

    private WorkOrderChecklist requireMaterialChecklist(WorkOrder workOrder) {
        if (workOrder.getMaterialChecklist() == null) {
            throw new EntityNotFoundException("Este parte no tiene plantilla de material asignada");
        }
        return workOrder.getMaterialChecklist();
    }

    private void applyMaterialChecklistTemplate(WorkOrder workOrder, MaterialChecklistTemplate template) {
        WorkOrderChecklist checklist = workOrder.getMaterialChecklist();
        if (checklist == null) {
            checklist = new WorkOrderChecklist();
            checklist.setWorkOrder(workOrder);
            workOrder.setMaterialChecklist(checklist);
        } else {
            checklist.getItems().clear();
        }

        final WorkOrderChecklist targetChecklist = checklist;

        targetChecklist.setSourceTemplateId(template.getId());
        targetChecklist.setSourceTemplateName(template.getName());
        targetChecklist.setAssignedAt(Instant.now());

        List<MaterialChecklistTemplateItem> resolvedTemplateItems = resolveChecklistTemplateItems(template);
        for (int index = 0; index < resolvedTemplateItems.size(); index += 1) {
            MaterialChecklistTemplateItem templateItem = resolvedTemplateItems.get(index);
            WorkOrderChecklistItem checklistItem = new WorkOrderChecklistItem();
            checklistItem.setChecklist(targetChecklist);
            checklistItem.setSourceTemplateItemId(templateItem.getId());
            checklistItem.setProductId(
                    templateItem.getProduct() != null ? templateItem.getProduct().getId() : null
            );
            checklistItem.setArticleName(templateItem.getArticleName());
            checklistItem.setReference(templateItem.getReference());
            checklistItem.setSortOrder(index);
            targetChecklist.getItems().add(checklistItem);
        }
    }

    private String mergeAutoMaterialObservations(String rawDescription, WorkOrderChecklist checklist) {
        String manualDescription = stripAutoMaterialObservations(rawDescription);
        String automaticSection = buildAutoMaterialObservations(checklist);

        if (automaticSection == null) {
            return manualDescription;
        }
        if (manualDescription == null || manualDescription.isBlank()) {
            return automaticSection;
        }
        return manualDescription + "\n\n" + automaticSection;
    }

    private String stripAutoMaterialObservations(String rawDescription) {
        if (rawDescription == null || rawDescription.isBlank()) {
            return null;
        }

        String marker = "Observaciones automáticas de material:";
        int markerIndex = rawDescription.indexOf(marker);
        String normalized = markerIndex >= 0
                ? rawDescription.substring(0, markerIndex).trim()
                : rawDescription.trim();
        return normalized.isEmpty() ? null : normalized;
    }

    private String buildAutoMaterialObservations(WorkOrderChecklist checklist) {
        if (checklist == null || checklist.getItems() == null || checklist.getItems().isEmpty()) {
            return null;
        }

        LinkedHashMap<String, Integer> quantitiesByItem = new LinkedHashMap<>();
        for (WorkOrderChecklistItem item : checklist.getItems()) {
            String key = (item.getArticleName() == null ? "" : item.getArticleName().trim())
                    + "||"
                    + (item.getReference() == null ? "" : item.getReference().trim());
            quantitiesByItem.merge(key, 1, Integer::sum);
        }

        List<String> repeatedItems = quantitiesByItem.entrySet().stream()
                .filter(entry -> entry.getValue() > 1)
                .map(entry -> {
                    String[] parts = entry.getKey().split("\\|\\|", 2);
                    String articleName = parts.length > 0 ? parts[0].trim() : "";
                    String reference = parts.length > 1 ? parts[1].trim() : "";
                    String label = reference.isEmpty()
                            ? articleName
                            : articleName + " (" + reference + ")";
                    return "- " + label + ": " + entry.getValue() + " unidades";
                })
                .toList();

        if (repeatedItems.isEmpty()) {
            return null;
        }

        return "Observaciones automáticas de material:\n"
                + String.join("\n", repeatedItems);
    }

    private WorkOrderChecklistDto toChecklistDto(WorkOrderChecklist checklist) {
        List<WorkOrderChecklistItemDto> items = checklist.getItems().stream()
                .sorted(Comparator.comparingInt(WorkOrderChecklistItem::getSortOrder).thenComparing(WorkOrderChecklistItem::getId))
                .map(this::toChecklistItemDto)
                .toList();

        return new WorkOrderChecklistDto(
                checklist.getId(),
                checklist.getSourceTemplateId(),
                checklist.getSourceTemplateName(),
                checklist.getAssignedAt(),
                items
        );
    }

    private WorkOrderChecklistItemDto toChecklistItemDto(WorkOrderChecklistItem item) {
        return new WorkOrderChecklistItemDto(
                item.getId(),
                item.getSourceTemplateItemId(),
                item.getProductId(),
                item.getArticleName(),
                item.getReference(),
                item.isChecked(),
                item.getCheckedAt(),
                item.getCheckedByWorker() != null ? item.getCheckedByWorker().getId() : null,
                item.getCheckedByWorker() != null ? item.getCheckedByWorker().getFullName() : null,
                item.getSortOrder()
        );
    }

    private MaterialRevisionRequestDto toMaterialRevisionRequestDto(MaterialRevisionRequest request) {
        return new MaterialRevisionRequestDto(
                request.getId(),
                request.getChecklistItemSnapshotId(),
                request.getSourceTemplateId(),
                request.getSourceTemplateItemId(),
                request.getProductId(),
                request.getArticleName(),
                request.getReference(),
                request.getObservations(),
                request.getStatus(),
                request.getRequestedByWorker() != null ? request.getRequestedByWorker().getId() : null,
                request.getRequestedByWorker() != null ? request.getRequestedByWorker().getFullName() : null,
                request.getCreatedAt(),
                request.getReviewedByWorker() != null ? request.getReviewedByWorker().getId() : null,
                request.getReviewedByWorker() != null ? request.getReviewedByWorker().getFullName() : null,
                request.getReviewedAt(),
                request.getResolutionNote()
        );
    }

    private List<MaterialChecklistTemplateItem> resolveChecklistTemplateItems(MaterialChecklistTemplate template) {
        LinkedHashMap<String, MaterialChecklistTemplateItem> itemsByKey = new LinkedHashMap<>();
        collectChecklistTemplateItems(template, new HashSet<>(), itemsByKey);
        return List.copyOf(itemsByKey.values());
    }

    private void collectChecklistTemplateItems(MaterialChecklistTemplate template,
                                               Set<Long> visitedTemplateIds,
                                               Map<String, MaterialChecklistTemplateItem> itemsByKey) {
        if (template.getId() != null && !visitedTemplateIds.add(template.getId())) {
            return;
        }

        if (template.getTemplateType() == MaterialChecklistTemplateType.COMPLETE && template.getBaseTemplate() != null) {
            collectChecklistTemplateItems(template.getBaseTemplate(), visitedTemplateIds, itemsByKey);
        }

        template.getItems().stream()
                .sorted(Comparator.comparingInt(MaterialChecklistTemplateItem::getSortOrder).thenComparing(MaterialChecklistTemplateItem::getId))
                .forEach(item -> itemsByKey.putIfAbsent(buildTemplateItemKey(item), item));
    }

    private String buildTemplateItemKey(MaterialChecklistTemplateItem item) {
        if (item.getProduct() != null && item.getProduct().getId() != null) {
            return "product:" + item.getProduct().getId();
        }
        return "reference:" + item.getReference().trim().toLowerCase(Locale.ROOT);
    }

    private WorkOrderAttachment mapAttachmentRequest(WorkOrder workOrder, AttachmentRequest item, Worker uploader) {
        WorkOrderAttachment att = new WorkOrderAttachment();
        att.setWorkOrder(workOrder);
        att.setFileUrl(inputSanitizer.optionalUrl(item.fileUrl(), 2000));
        String sanitizedFileUrl = att.getFileUrl();
        WorkOrderMediaService.StoredMediaMetadata storedMedia = workOrderMediaService.inspectStoredMedia(sanitizedFileUrl);
        att.setFileType(inputSanitizer.requiredText(item.fileType(), "El tipo de archivo", 255));
        att.setContentType(inputSanitizer.optionalText(storedMedia.contentType(), 255));
        att.setOriginalFileName(inputSanitizer.optionalText(item.originalFileName(), 255));
        att.setCapturedAt(item.capturedAt());
        att.setUploadedAt(Instant.now());
        att.setLatitude(item.latitude());
        att.setLongitude(item.longitude());
        att.setFileSizeBytes(storedMedia.fileSizeBytes());
        att.setStorageObjectKey(storedMedia.objectKey());
        att.setSha256Hex(storedMedia.sha256Hex());
        att.setUploadedByWorker(uploader);
        att.setWatermarked(item.watermarked());
        att.setAudioRemoved(item.audioRemoved());
        return att;
    }

    private WorkOrderAttachment mapLegacyAttachmentUrl(WorkOrder workOrder, String url, Worker uploader) {
        String sanitizedFileUrl = inputSanitizer.optionalUrl(url, 2000);
        WorkOrderMediaService.StoredMediaMetadata storedMedia = workOrderMediaService.inspectStoredMedia(sanitizedFileUrl);
        WorkOrderAttachment att = new WorkOrderAttachment();
        att.setWorkOrder(workOrder);
        att.setFileUrl(sanitizedFileUrl);
        att.setFileType(inferType(sanitizedFileUrl));
        att.setContentType(inputSanitizer.optionalText(storedMedia.contentType(), 255));
        att.setUploadedAt(Instant.now());
        att.setFileSizeBytes(storedMedia.fileSizeBytes());
        att.setStorageObjectKey(storedMedia.objectKey());
        att.setSha256Hex(storedMedia.sha256Hex());
        att.setUploadedByWorker(uploader);
        return att;
    }

    private WorkOrderAttachment buildAttachmentEntity(WorkOrder workOrder,
                                                      UploadedAttachmentDto attachment,
                                                      Worker uploader,
                                                      String uploadIp,
                                                      String uploadUserAgent) {
        WorkOrderAttachment att = new WorkOrderAttachment();
        att.setWorkOrder(workOrder);
        att.setFileUrl(attachment.fileUrl());
        att.setFileType(attachment.fileType());
        att.setContentType(inputSanitizer.optionalText(attachment.contentType(), 255));
        att.setOriginalFileName(inputSanitizer.optionalText(attachment.originalFileName(), 255));
        att.setCapturedAt(attachment.capturedAt());
        att.setUploadedAt(attachment.uploadedAt() == null ? Instant.now() : attachment.uploadedAt());
        att.setLatitude(attachment.latitude());
        att.setLongitude(attachment.longitude());
        att.setFileSizeBytes(attachment.fileSizeBytes());
        att.setStorageObjectKey(inputSanitizer.optionalText(attachment.storageObjectKey(), 2000));
        att.setSha256Hex(inputSanitizer.optionalText(attachment.sha256Hex(), 64));
        att.setUploadedByWorker(uploader);
        att.setUploadIp(inputSanitizer.optionalText(uploadIp, 128));
        att.setUploadUserAgent(inputSanitizer.optionalText(uploadUserAgent, 1000));
        att.setWatermarked(attachment.watermarked());
        att.setAudioRemoved(attachment.audioRemoved());
        return att;
    }

    private void signAllAttachmentEvidence(WorkOrder workOrder) {
        for (WorkOrderAttachment attachment : workOrder.getAttachments()) {
            signAttachmentEvidence(workOrder, attachment);
        }
    }

    private void signAttachmentEvidence(WorkOrder workOrder, WorkOrderAttachment attachment) {
        if (attachment.getUploadedAt() == null) {
            attachment.setUploadedAt(Instant.now());
        }
        if (attachment.getFileUrl() == null || attachment.getFileUrl().isBlank()) {
            return;
        }
        if (attachment.getSha256Hex() == null || attachment.getSha256Hex().isBlank()
                || attachment.getStorageObjectKey() == null || attachment.getStorageObjectKey().isBlank()) {
            WorkOrderMediaService.StoredMediaMetadata storedMedia = workOrderMediaService.inspectStoredMedia(attachment.getFileUrl());
            attachment.setContentType(inputSanitizer.optionalText(storedMedia.contentType(), 255));
            attachment.setFileSizeBytes(storedMedia.fileSizeBytes());
            attachment.setStorageObjectKey(storedMedia.objectKey());
            attachment.setSha256Hex(storedMedia.sha256Hex());
        }
        attachment.setServerSignature(workOrderEvidenceService.signAttachment(workOrder, attachment));
    }

    private void sealWorkOrderEvidence(WorkOrder workOrder) {
        Instant sealedAt = Instant.now();
        WorkOrderEvidenceService.WorkOrderSeal seal = workOrderEvidenceService.sealWorkOrder(workOrder, sealedAt);
        workOrder.setEvidenceSealedAt(sealedAt);
        workOrder.setEvidenceManifestHash(seal.manifestHash());
        workOrder.setEvidenceServerSignature(seal.serverSignature());
    }

    private void ensureNotSealed(WorkOrder workOrder) {
        if (isSealed(workOrder)) {
            throw new AccessDeniedException("El parte ya esta sellado y no admite cambios");
        }
    }

    public WorkOrderEvidenceReport generateEvidenceReport(Long workOrderId, String currentUserEmail) {
        WorkOrder workOrder = workOrderRepository.findById(workOrderId)
                .orElseThrow(() -> new EntityNotFoundException("Parte no encontrado"));
        Worker current = requireWorkerByEmail(currentUserEmail);
        if (!isAdmin(current)) {
            throw new AccessDeniedException("Solo un administrador puede descargar el acta de integridad");
        }
        if (workOrder.getAttachments() == null || workOrder.getAttachments().isEmpty()) {
            throw new IllegalArgumentException("Este parte no tiene adjuntos para generar el acta de integridad");
        }
        if (workOrder.getSignedAt() == null) {
            throw new IllegalArgumentException("El acta de integridad solo se puede descargar cuando el parte está firmado");
        }
        if (workOrder.getEvidenceSealedAt() == null
                || workOrder.getEvidenceManifestHash() == null || workOrder.getEvidenceManifestHash().isBlank()
                || workOrder.getEvidenceServerSignature() == null || workOrder.getEvidenceServerSignature().isBlank()) {
            throw new IllegalArgumentException("El acta de integridad solo está disponible cuando la evidencia del parte ya ha sido sellada");
        }
        byte[] pdfBytes = workOrderEvidencePdfService.buildReport(workOrder);
        return new WorkOrderEvidenceReport(
                "parte_" + workOrder.getId() + "_acta_integridad_evidencias.pdf",
                pdfBytes
        );
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

    public record WorkOrderEvidenceReport(
            String fileName,
            byte[] content
    ) {
    }
}
