package com.navalgo.backend.workorder;

import com.navalgo.backend.fleet.Owner;
import com.navalgo.backend.fleet.OwnerRepository;
import com.navalgo.backend.fleet.Vessel;
import com.navalgo.backend.fleet.VesselRepository;
import com.navalgo.backend.worker.Worker;
import com.navalgo.backend.worker.WorkerRepository;
import jakarta.persistence.EntityNotFoundException;
import org.springframework.stereotype.Service;

import java.util.*;

@Service
public class WorkOrderService {

    private final WorkOrderRepository workOrderRepository;
    private final OwnerRepository ownerRepository;
    private final VesselRepository vesselRepository;
    private final WorkerRepository workerRepository;

    public WorkOrderService(WorkOrderRepository workOrderRepository,
                            OwnerRepository ownerRepository,
                            VesselRepository vesselRepository,
                            WorkerRepository workerRepository) {
        this.workOrderRepository = workOrderRepository;
        this.ownerRepository = ownerRepository;
        this.vesselRepository = vesselRepository;
        this.workerRepository = workerRepository;
    }

    public List<WorkOrderDto> findAll() {
        return workOrderRepository.findAll().stream().map(this::toDto).toList();
    }

    public List<WorkOrderDto> findByWorker(Long workerId) {
        return workOrderRepository.findByAssignedWorkersId(workerId).stream().map(this::toDto).toList();
    }

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

        if (request.attachmentUrls() != null) {
            for (String url : request.attachmentUrls()) {
                WorkOrderAttachment att = new WorkOrderAttachment();
                att.setWorkOrder(workOrder);
                att.setFileUrl(url);
                att.setFileType(inferType(url));
                workOrder.getAttachments().add(att);
            }
        }

        return toDto(workOrderRepository.save(workOrder));
    }

    public WorkOrderDto updateStatus(Long id, UpdateWorkOrderStatusRequest request) {
        WorkOrder workOrder = workOrderRepository.findById(id)
                .orElseThrow(() -> new EntityNotFoundException("Parte no encontrado"));
        workOrder.setStatus(request.status());
        return toDto(workOrderRepository.save(workOrder));
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
                w.getCreatedAt()
        );
    }

    private String inferType(String fileUrl) {
        String normalized = fileUrl.toLowerCase(Locale.ROOT);
        if (normalized.endsWith(".mp4") || normalized.endsWith(".mov") || normalized.endsWith(".avi")) {
            return "VIDEO";
        }
        return "IMAGE";
    }
}
