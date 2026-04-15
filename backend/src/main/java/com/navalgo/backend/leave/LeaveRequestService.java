package com.navalgo.backend.leave;

import com.navalgo.backend.notification.NotificationService;
import com.navalgo.backend.notification.NotificationType;
import com.navalgo.backend.worker.Worker;
import com.navalgo.backend.worker.WorkerRepository;
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

    public LeaveRequestService(LeaveRequestRepository repository,
                               WorkerRepository workerRepository,
                               NotificationService notificationService) {
        this.repository = repository;
        this.workerRepository = workerRepository;
        this.notificationService = notificationService;
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

        if (entity.getStatus() == LeaveStatus.APPROVED && request.status() != LeaveStatus.APPROVED) {
            throw new IllegalArgumentException("Una solicitud aceptada no puede desaprobarse");
        }

        if (request.status() == LeaveStatus.APPROVED && entity.getStatus() != LeaveStatus.APPROVED) {
            validateRequestedDays(entity.getWorker(), entity.getStartDate(), entity.getEndDate(), entity.getId());
            notificationService.notifyWorker(
                    entity.getWorker().getId(),
                    "Vacaciones aceptadas",
                    "Tu solicitud de vacaciones ha sido aceptada.",
                    "AUSENCIAS",
                    NotificationType.SUCCESS
            );
        }

        if (request.status() == LeaveStatus.REJECTED) {
            notificationService.notifyWorker(
                    entity.getWorker().getId(),
                    "Vacaciones rechazadas",
                    "Tu solicitud de vacaciones ha sido rechazada.",
                    "AUSENCIAS",
                    NotificationType.WARNING
            );
        }

        entity.setStatus(request.status());
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
        LocalDate contractStart = worker.getContractStartDate();
        LocalDate today = LocalDate.now();
        if (contractStart == null || contractStart.isAfter(today)) {
            return 0.0;
        }

        long completedMonths = ChronoUnit.MONTHS.between(contractStart, today);
        return completedMonths * 2.5;
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
