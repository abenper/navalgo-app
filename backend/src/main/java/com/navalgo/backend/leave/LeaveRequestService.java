package com.navalgo.backend.leave;

import com.navalgo.backend.common.InputSanitizer;
import com.navalgo.backend.notification.NotificationService;
import com.navalgo.backend.notification.NotificationType;
import com.navalgo.backend.timetracking.TimeEntry;
import com.navalgo.backend.timetracking.TimeEntryRepository;
import com.navalgo.backend.timetracking.TimeEntryWorkSite;
import com.navalgo.backend.worker.Worker;
import com.navalgo.backend.worker.WorkerRepository;
import jakarta.persistence.EntityNotFoundException;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.text.Normalizer;
import java.time.LocalDate;
import java.time.ZoneId;
import java.time.temporal.ChronoUnit;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;

@Service
@Transactional(readOnly = true)
public class LeaveRequestService {

    private static final double VACATION_DAYS_PER_CALENDAR_DAY = 31.0 / 365.0;
    private static final int TRAVEL_STREAK_DAYS = 15;

    private final LeaveRequestRepository repository;
    private final WorkerRepository workerRepository;
    private final NotificationService notificationService;
    private final TimeEntryRepository timeEntryRepository;
    private final InputSanitizer inputSanitizer;

    public LeaveRequestService(LeaveRequestRepository repository,
                               WorkerRepository workerRepository,
                               NotificationService notificationService,
                               TimeEntryRepository timeEntryRepository,
                               InputSanitizer inputSanitizer) {
        this.repository = repository;
        this.workerRepository = workerRepository;
        this.notificationService = notificationService;
        this.timeEntryRepository = timeEntryRepository;
        this.inputSanitizer = inputSanitizer;
    }

    @Transactional
    public LeaveRequestDto create(CreateLeaveRequest request) {
        return createInternal(
                request.workerId(),
                request.reason(),
                request.startDate(),
                request.endDate(),
                LeaveStatus.PENDING
        );
    }

    @Transactional
    public LeaveRequestDto adminAssign(AdminAssignLeaveRequest request) {
        return createInternal(
                request.workerId(),
                request.reason(),
                request.startDate(),
                request.endDate(),
                LeaveStatus.APPROVED
        );
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
        String reason = request.reason() != null
                ? inputSanitizer.requiredText(request.reason(), "El motivo", 255)
                : entity.getReason();

        if (reason.isBlank()) {
            throw new IllegalArgumentException("El motivo es obligatorio");
        }

        validateRequestedDays(entity.getWorker(), reason, startDate, endDate, entity.getId());

        entity.setReason(reason);
        entity.setStartDate(startDate);
        entity.setEndDate(endDate);
        entity.setStatus(LeaveStatus.PENDING);

        notificationService.notifyAdmins(
                "Solicitud de ausencia modificada",
                entity.getWorker().getFullName() + " ha modificado una solicitud de ausencia.",
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

        long accrued = calculateAccruedDays(worker);
        long bonus = calculateTravelBonusDays(worker.getId());
        long consumed = calculateConsumedDays(worker.getId(), null);
        long available = accrued + bonus - consumed;

        return new LeaveBalanceDto(
                worker.getId(),
                worker.getFullName(),
                accrued,
                bonus,
                consumed,
                available
        );
    }

    private LeaveRequestDto createInternal(Long workerId,
                                           String reason,
                                           LocalDate startDate,
                                           LocalDate endDate,
                                           LeaveStatus status) {
        Worker worker = workerRepository.findById(workerId)
                .orElseThrow(() -> new EntityNotFoundException("Trabajador no encontrado"));

        String sanitizedReason = inputSanitizer.requiredText(reason, "El motivo", 255);
        validateRequestedDays(worker, sanitizedReason, startDate, endDate, null);

        LeaveRequestEntity entity = new LeaveRequestEntity();
        entity.setWorker(worker);
        entity.setReason(sanitizedReason);
        entity.setStartDate(startDate);
        entity.setEndDate(endDate);
        entity.setStatus(status);
        LeaveRequestEntity saved = repository.save(entity);

        if (status == LeaveStatus.PENDING) {
            notificationService.notifyAdmins(
                    "Nueva solicitud de ausencia",
                    worker.getFullName() + " ha enviado una nueva solicitud de ausencia.",
                    "AUSENCIAS",
                    NotificationType.INFO
            );
        }

        if (status == LeaveStatus.APPROVED) {
            notificationService.notifyWorker(
                    worker.getId(),
                    "Ausencia asignada",
                    "Se te ha asignado una nueva ausencia.",
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
            validateRequestedDays(
                    entity.getWorker(),
                    entity.getReason(),
                    entity.getStartDate(),
                    entity.getEndDate(),
                    entity.getId()
            );
            notificationService.notifyWorker(
                    entity.getWorker().getId(),
                    "Solicitud aceptada",
                    "Tu solicitud de ausencia ha sido aceptada.",
                    "AUSENCIAS",
                    NotificationType.SUCCESS
            );
        } else if (newStatus == LeaveStatus.REJECTED) {
            notificationService.notifyWorker(
                    entity.getWorker().getId(),
                    "Solicitud rechazada",
                    "Tu solicitud de ausencia ha sido rechazada.",
                    "AUSENCIAS",
                    NotificationType.WARNING
            );
        } else if (newStatus == LeaveStatus.CANCELLED) {
            notificationService.notifyWorker(
                    entity.getWorker().getId(),
                    "Solicitud cancelada",
                    "Tu solicitud de ausencia ha sido cancelada.",
                    "AUSENCIAS",
                    NotificationType.WARNING
            );
        }

        entity.setStatus(newStatus);
    }

    private void validateRequestedDays(Worker worker,
                                       String reason,
                                       LocalDate startDate,
                                       LocalDate endDate,
                                       Long excludeRequestId) {
        if (endDate.isBefore(startDate)) {
            throw new IllegalArgumentException("La fecha fin no puede ser menor que la fecha inicio");
        }

        if (!isVacationReason(reason)) {
            return;
        }
    }

    private long calculateAccruedDays(Worker worker) {
        LocalDate contractStartDate = worker.getContractStartDate() != null
                ? worker.getContractStartDate()
                : LocalDate.now();
        LocalDate today = LocalDate.now();

        if (contractStartDate.isAfter(today)) {
            return 0L;
        }

        long calendarDaysWorked = ChronoUnit.DAYS.between(contractStartDate, today) + 1;
        return Math.round(calendarDaysWorked * VACATION_DAYS_PER_CALENDAR_DAY);
    }

    private long calculateConsumedDays(Long workerId, Long excludeRequestId) {
        List<LeaveRequestEntity> consumedRequests = repository.findByWorkerIdAndStatusIn(
                workerId,
                Set.of(LeaveStatus.PENDING, LeaveStatus.APPROVED)
        );

        return consumedRequests.stream()
                .filter(item -> isVacationReason(item.getReason()))
                .filter(item -> excludeRequestId == null || !item.getId().equals(excludeRequestId))
                .mapToLong(item -> ChronoUnit.DAYS.between(item.getStartDate(), item.getEndDate()) + 1)
                .sum();
    }

    private long calculateTravelBonusDays(Long workerId) {
        List<TimeEntry> entries = timeEntryRepository.findByWorkerIdOrderByClockInAsc(workerId);
        Map<LocalDate, TimeEntryWorkSite> workSiteByDate = new LinkedHashMap<>();
        ZoneId zoneId = ZoneId.systemDefault();

        for (TimeEntry entry : entries) {
            LocalDate workDate = entry.getClockIn().atZone(zoneId).toLocalDate();
            TimeEntryWorkSite currentWorkSite = workSiteByDate.get(workDate);

            if (currentWorkSite == null) {
                workSiteByDate.put(workDate, entry.getWorkSite());
                continue;
            }

            if (currentWorkSite != entry.getWorkSite()) {
                workSiteByDate.put(workDate, TimeEntryWorkSite.WORKSHOP);
            }
        }

        int streak = 0;
        long bonusDays = 0;
        LocalDate previousTravelDay = null;

        for (Map.Entry<LocalDate, TimeEntryWorkSite> item : workSiteByDate.entrySet()) {
            LocalDate currentDay = item.getKey();
            TimeEntryWorkSite workSite = item.getValue();

            if (workSite != TimeEntryWorkSite.TRAVEL) {
                streak = 0;
                previousTravelDay = null;
                continue;
            }

            if (previousTravelDay != null && isNextBusinessDay(previousTravelDay, currentDay)) {
                streak++;
            } else {
                streak = 1;
            }

            previousTravelDay = currentDay;
            if (streak % TRAVEL_STREAK_DAYS == 0) {
                bonusDays++;
            }
        }

        return bonusDays;
    }

    private boolean isNextBusinessDay(LocalDate previousDay, LocalDate currentDay) {
        LocalDate nextBusinessDay = previousDay.plusDays(1);
        while (nextBusinessDay.getDayOfWeek().getValue() >= 6) {
            nextBusinessDay = nextBusinessDay.plusDays(1);
        }
        return nextBusinessDay.equals(currentDay);
    }

    private boolean isVacationReason(String reason) {
        return normalizeReason(reason).contains("vacacion");
    }

    private String normalizeReason(String reason) {
        if (reason == null) {
            return "";
        }

        String normalized = Normalizer.normalize(reason, Normalizer.Form.NFD)
                .replaceAll("\\p{M}+", "");
        return normalized.trim().toLowerCase(Locale.ROOT);
    }
}
