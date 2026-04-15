package com.navalgo.backend.workorder;

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

import java.util.*;

@Service
@Transactional(readOnly = true)
public class WorkOrderService {

    private final WorkOrderRepository workOrderRepository;
    private final OwnerRepository ownerRepository;
    private final VesselRepository vesselRepository;
    private final WorkerRepository workerRepository;
    private final NotificationService notificationService;

    public WorkOrderService(WorkOrderRepository workOrderRepository,
                            OwnerRepository ownerRepository,
                            VesselRepository vesselRepository,
                            WorkerRepository workerRepository,
                            NotificationService notificationService) {
        this.workOrderRepository = workOrderRepository;
        this.ownerRepository = ownerRepository;
        this.vesselRepository = vesselRepository;
        this.workerRepository = workerRepository;
        this.notificationService = notificationService;
    }

    public List<WorkOrderDto> findAll() {
        return workOrderRepository.findAll().stream().map(this::toDto).toList();
    }

    public List<WorkOrderDto> findByWorker(Long workerId) {
        return workOrderRepository.findByAssignedWorkersId(workerId).stream().map(this::toDto).toList();
    }

    public Long findWorkerIdByEmail(String email) {
        return workerRepository.findByEmailIgnoreCase(email)
                .orElseThrow(() -> new EntityNotFoundException("Usuario no encontrado"))
                .getId();
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
        workOrder.setTitle(request.title());
        workOrder.setDescription(request.description());
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
                log.setEngineLabel(engineReq.engineLabel());
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
                att.setFileUrl(url);
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
        if (!isAdmin(current) && !(isAssignedToWorkOrder(current, workOrder) && current.isCanEditWorkOrders())) {
            throw new AccessDeniedException("No tienes permiso para editar este parte");
        }

        if (request.title() != null && !request.title().isBlank()) {
            workOrder.setTitle(request.title().trim());
        }
        if (request.description() != null) {
            workOrder.setDescription(request.description());
        }
        if (request.priority() != null) {
            workOrder.setPriority(request.priority());
        }
        if (request.status() != null) {
            workOrder.setStatus(request.status());
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
                log.setEngineLabel(engineReq.engineLabel());
                log.setHours(engineReq.hours());
                workOrder.getEngineHourLogs().add(log);
            }
        }

        if (request.attachmentUrls() != null) {
            workOrder.getAttachments().clear();
            for (String url : request.attachmentUrls()) {
                WorkOrderAttachment att = new WorkOrderAttachment();
                att.setWorkOrder(workOrder);
                att.setFileUrl(url);
                att.setFileType(inferType(url));
                workOrder.getAttachments().add(att);
            }
        }

        if (request.attachments() != null) {
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

    private Worker requireWorkerByEmail(String email) {
        return workerRepository.findByEmailIgnoreCase(email)
                .orElseThrow(() -> new EntityNotFoundException("Usuario no encontrado"));
    }

    private boolean isAdmin(Worker worker) {
        return worker.getRole() == com.navalgo.backend.common.Role.ADMIN;
    }

    private boolean isAssignedToWorkOrder(Worker worker, WorkOrder workOrder) {
        return workOrder.getAssignedWorkers().stream().anyMatch(w -> w.getId().equals(worker.getId()));
    }

    private WorkOrderDto toDto(WorkOrder w) {
        return new WorkOrderDto(
                w.getId(),
                w.getTitle(),
                w.getDescription(),
                w.getStatus(),
                w.getPriority(),
                w.getOwner().getId(),
                w.getOwner().getDisplayName(),
                w.getVessel() != null ? w.getVessel().getId() : null,
                w.getVessel() != null ? w.getVessel().getName() : null,
                w.getAssignedWorkers().stream().map(Worker::getId).toList(),
                w.getAssignedWorkers().stream().map(Worker::getFullName).toList(),
                w.getEngineHourLogs().stream().map(e -> new EngineHourRequest(e.getEngineLabel(), e.getHours())).toList(),
                w.getAttachments().stream().map(WorkOrderAttachment::getFileUrl).toList(),
                w.getAttachments().stream().map(AttachmentInfoDto::from).toList(),
                w.getCreatedAt()
        );
    }

    private WorkOrderAttachment mapAttachmentRequest(WorkOrder workOrder, AttachmentRequest item) {
        WorkOrderAttachment att = new WorkOrderAttachment();
        att.setWorkOrder(workOrder);
        att.setFileUrl(item.fileUrl());
        att.setFileType(item.fileType());
        att.setOriginalFileName(item.originalFileName());
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
}
