package com.navalgo.backend.leave;

import com.navalgo.backend.notification.NotificationService;
import com.navalgo.backend.notification.NotificationType;
import com.navalgo.backend.timetracking.TimeEntryRepository;
import com.navalgo.backend.worker.Worker;
import com.navalgo.backend.worker.WorkerRepository;
import org.springframework.security.access.AccessDeniedException;
import jakarta.persistence.EntityNotFoundException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDate;
import java.time.temporal.ChronoUnit;
import java.util.List;
import java.util.Set;

@Service
@Transactional(readOnly = true)
public class LeaveRequestService {

    private final LeaveRequestRepository repository;
    private final WorkerRepository workerRepository;
    private final NotificationService notificationService;
    private final TimeEntryRepository timeEntryRepository;

    // 22 vacation days per year / 220 typical working days per year = 0.1 days vacation per day worked
    private static final double VACATION_DAYS_PER_WORKED_DAY = 22.0 / 220.0;

    public LeaveRequestService(LeaveRequestRepository repository,
                               WorkerRepository workerRepository,
                               NotificationService notificationService,
                               TimeEntryRepository timeEntryRepository) {
        this.repository = repository;
        this.workerRepository = workerRepository;
        this.notificationService = notificationService;
        this.timeEntryRepository = timeEntryRepository;
    }

    @Transactional
    public LeaveRequestDto create(CreateLeaveRequest request) {
        return createInternal(request.workerId(), request.reason(), request.startDate(), request.endDate(), LeaveStatus.PENDING);
    }

    @Transactional
    public LeaveRequestDto adminAssign(AdminAssignLeaveRequest request) {
        return createInternal(request.workerId(), request.reason(), request.startDate(), request.endDate(), LeaveStatus.APPROVED);
    }

    public List<LeaveRequestDto> list(Long workerId) {
        if (workerId == null) {
            return repository.findAll().stream().map(LeaveRequestDto::from).toList();
        }
        return repository.findByWorkerIdOrderByStartDateDesc(workerId)
                .stream()
                .map(LeaveRequestDto::from)
                .toList();
    }

    @Transactional
    public LeaveRequestDto updateStatus(Long id, UpdateLeaveStatusRequest request) {
        LeaveRequestEntity entity = repository.findById(id)
                .orElseThrow(() -> new EntityNotFoundException("Solicitud no encontrada"));
        applyStatusChange(entity, request.status());
        return LeaveRequestDto.from(repository.save(entity));
    }

    @Transactional
    public LeaveRequestDto updateRequest(Long id,
                                         UpdateLeaveRequest request,
                                         Long currentWorkerId,
                                         boolean isAdmin) {
        LeaveRequestEntity entity = repository.findById(id)
                .orElseThrow(() -> new EntityNotFoundException("Solicitud no encontrada"));

        ensureCanModify(entity, currentWorkerId, isAdmin);

        LocalDate startDate = request.startDate() != null ? request.startDate() : entity.getStartDate();
        LocalDate endDate = request.endDate() != null ? request.endDate() : entity.getEndDate();
        String reason = request.reason() != null ? request.reason().trim() : entity.getReason();

        if (reason.isBlank()) {
            throw new IllegalArgumentException("El motivo es obligatorio");
        }

        validateRequestedDays(entity.getWorker(), startDate, endDate, entity.getId());

        entity.setReason(reason);
        entity.setStartDate(startDate);
        entity.setEndDate(endDate);

        // Any edit requires admin confirmation again.
        entity.setStatus(LeaveStatus.PENDING);

        notificationService.notifyAdmins(
                "Solicitud de vacaciones modificada",
                entity.getWorker().getFullName() + " ha modificado una solicitud de vacaciones.",
                "AUSENCIAS",
                NotificationType.INFO
        );

        return LeaveRequestDto.from(repository.save(entity));
    }

    @Transactional
    public LeaveRequestDto cancelRequest(Long id, Long currentWorkerId, boolean isAdmin) {
        LeaveRequestEntity entity = repository.findById(id)
                .orElseThrow(() -> new EntityNotFoundException("Solicitud no encontrada"));

        ensureCanModify(entity, currentWorkerId, isAdmin);

        applyStatusChange(entity, LeaveStatus.CANCELLED);
        return LeaveRequestDto.from(repository.save(entity));
    }

    public LeaveBalanceDto getBalance(Long workerId) {
        Worker worker = workerRepository.findById(workerId)
                .orElseThrow(() -> new EntityNotFoundException("Trabajador no encontrado"));

        double accrued = calculateAccruedDays(worker);
        long consumed = calculateConsumedDays(worker.getId(), null);
        double available = Math.max(0.0, accrued - consumed);

        return new LeaveBalanceDto(
                worker.getId(),
                worker.getFullName(),
                roundDays(accrued),
                consumed,
                roundDays(available)
        );
    }

    private LeaveRequestDto createInternal(Long workerId, String reason, LocalDate startDate, LocalDate endDate, LeaveStatus status) {
        Worker worker = workerRepository.findById(workerId)
                .orElseThrow(() -> new EntityNotFoundException("Trabajador no encontrado"));

        validateRequestedDays(worker, startDate, endDate, null);

        LeaveRequestEntity entity = new LeaveRequestEntity();
        entity.setWorker(worker);
        entity.setReason(reason);
        entity.setStartDate(startDate);
        entity.setEndDate(endDate);
        entity.setStatus(status);
        LeaveRequestEntity saved = repository.save(entity);

        if (status == LeaveStatus.PENDING) {
            notificationService.notifyAdmins(
                    "Nueva solicitud de vacaciones",
                    worker.getFullName() + " ha solicitado vacaciones. Haz click para ver mas informacion.",
                    "AUSENCIAS",
                    NotificationType.INFO
            );
        }

        if (status == LeaveStatus.APPROVED) {
            notificationService.notifyWorker(
                    worker.getId(),
                    "Vacaciones asignadas",
                    "Se te han asignado nuevas vacaciones.",
                    "AUSENCIAS",
                    NotificationType.SUCCESS
            );
        }

        return LeaveRequestDto.from(saved);
    }

    private void ensureCanModify(LeaveRequestEntity entity, Long currentWorkerId, boolean isAdmin) {
        if (!isAdmin && (currentWorkerId == null || !entity.getWorker().getId().equals(currentWorkerId))) {
            throw new AccessDeniedException("Solo puedes modificar tus propias solicitudes");
        }
    }

    private void applyStatusChange(LeaveRequestEntity entity, LeaveStatus newStatus) {
        if (newStatus == LeaveStatus.APPROVED) {
            validateRequestedDays(entity.getWorker(), entity.getStartDate(), entity.getEndDate(), entity.getId());
            notificationService.notifyWorker(
                    entity.getWorker().getId(),
                    "Vacaciones aceptadas",
                    "Tu solicitud de vacaciones ha sido aceptada.",
                    "AUSENCIAS",
                    NotificationType.SUCCESS
            );
        } else if (newStatus == LeaveStatus.REJECTED) {
            notificationService.notifyWorker(
                    entity.getWorker().getId(),
                    "Vacaciones rechazadas",
                    "Tu solicitud de vacaciones ha sido rechazada.",
                    "AUSENCIAS",
                    NotificationType.WARNING
            );
        } else if (newStatus == LeaveStatus.CANCELLED) {
            notificationService.notifyWorker(
                    entity.getWorker().getId(),
                    "Vacaciones canceladas",
                    "Tu solicitud de vacaciones ha sido cancelada.",
                    "AUSENCIAS",
                    NotificationType.WARNING
            );
        }

        entity.setStatus(newStatus);
    }

    private void validateRequestedDays(Worker worker, LocalDate startDate, LocalDate endDate, Long excludeRequestId) {
        if (endDate.isBefore(startDate)) {
            throw new IllegalArgumentException("La fecha fin no puede ser menor que la fecha inicio");
        }

        long requested = ChronoUnit.DAYS.between(startDate, endDate) + 1;
        double accrued = calculateAccruedDays(worker);
        long consumed = calculateConsumedDays(worker.getId(), excludeRequestId);
        double available = accrued - consumed;

        if (requested > available) {
            throw new IllegalArgumentException("No tienes dias disponibles suficientes para esta solicitud");
        }
    }

    private double calculateAccruedDays(Worker worker) {
        long workedDays = timeEntryRepository.countDistinctWorkedDays(worker.getId());
        return workedDays * VACATION_DAYS_PER_WORKED_DAY;
    }

    private long calculateConsumedDays(Long workerId, Long excludeRequestId) {
        List<LeaveRequestEntity> consumedRequests = repository.findByWorkerIdAndStatusIn(
                workerId,
                Set.of(LeaveStatus.PENDING, LeaveStatus.APPROVED)
        );

        return consumedRequests.stream()
                .filter(item -> excludeRequestId == null || !item.getId().equals(excludeRequestId))
                .mapToLong(item -> ChronoUnit.DAYS.between(item.getStartDate(), item.getEndDate()) + 1)
                .sum();
    }

    private double roundDays(double value) {
        return Math.round(value * 10.0) / 10.0;
    }
}
