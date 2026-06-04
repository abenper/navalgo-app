package com.navalgo.backend.timetracking;

import com.navalgo.backend.budget.Budget;
import com.navalgo.backend.budget.BudgetRepository;
import com.navalgo.backend.budget.BudgetStatus;
import com.navalgo.backend.common.Role;
import com.navalgo.backend.leave.LeaveRequestEntity;
import com.navalgo.backend.leave.LeaveRequestRepository;
import com.navalgo.backend.leave.LeaveStatus;
import com.navalgo.backend.workorder.WorkOrder;
import com.navalgo.backend.workorder.WorkOrderRepository;
import com.navalgo.backend.workorder.WorkOrderStatus;
import com.navalgo.backend.worker.Worker;
import com.navalgo.backend.worker.WorkerRepository;
import jakarta.persistence.EntityNotFoundException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.text.Normalizer;
import java.time.Instant;
import java.time.DayOfWeek;
import java.time.LocalDate;
import java.time.LocalTime;
import java.time.YearMonth;
import java.time.ZoneId;
import java.time.ZonedDateTime;
import java.time.temporal.ChronoUnit;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;
import java.util.EnumSet;

@Service
@Transactional(readOnly = true)
public class TimeTrackingService {

    private static final ZoneId BUSINESS_ZONE = TimeEntryClockOuts.BUSINESS_ZONE;

    private final LeaveRequestRepository leaveRequestRepository;
    private final TimeEntryRepository timeEntryRepository;
    private final WorkOrderRepository workOrderRepository;
    private final WorkerRepository workerRepository;
    private final BudgetRepository budgetRepository;

    public TimeTrackingService(LeaveRequestRepository leaveRequestRepository,
                               TimeEntryRepository timeEntryRepository,
                               WorkOrderRepository workOrderRepository,
                               WorkerRepository workerRepository,
                               BudgetRepository budgetRepository) {
        this.leaveRequestRepository = leaveRequestRepository;
        this.timeEntryRepository = timeEntryRepository;
        this.workOrderRepository = workOrderRepository;
        this.workerRepository = workerRepository;
        this.budgetRepository = budgetRepository;
    }

    @Transactional
    public TimeEntryDto clockIn(Long workerId,
                                TimeEntryWorkSite workSite,
                                Instant plannedClockOut,
                                Double latitude,
                                Double longitude) {
        Worker worker = workerRepository.findById(workerId)
                .orElseThrow(() -> new EntityNotFoundException("Trabajador no encontrado"));

        if (workSite == null) {
            throw new IllegalArgumentException("Debes indicar si el fichaje es en taller o en viaje");
        }

        timeEntryRepository.findFirstByWorkerIdAndClockOutIsNullOrderByClockInDesc(workerId)
                .ifPresent(entry -> {
                    throw new IllegalArgumentException("El trabajador ya tiene un fichaje abierto");
                });

        Instant now = Instant.now();
        validatePlannedClockOut(now, plannedClockOut);
        validateClockInLocation(latitude, longitude);

        TimeEntry entry = new TimeEntry();
        entry.setWorker(worker);
        entry.setClockIn(now);
        entry.setWorkSite(workSite);
        entry.setPlannedClockOut(plannedClockOut);
        entry.setClockInLatitude(latitude);
        entry.setClockInLongitude(longitude);

        return TimeEntryDto.from(timeEntryRepository.save(entry));
    }

    @Transactional
    public TimeEntryDto clockOut(Long workerId) {
        TimeEntry entry = timeEntryRepository.findFirstByWorkerIdAndClockOutIsNullOrderByClockInDesc(workerId)
                .orElseThrow(() -> new IllegalArgumentException("No hay fichaje abierto para ese trabajador"));

        entry.setClockOut(Instant.now());
        return TimeEntryDto.from(timeEntryRepository.save(entry));
    }

    public List<TimeEntryDto> listByWorker(Long workerId) {
        return timeEntryRepository.findByWorkerIdOrderByClockInDesc(workerId)
                .stream()
                .map(TimeEntryDto::from)
                .toList();
    }

    @Transactional
    public TimeEntryDto createManualEntry(CreateTimeEntryRequest request) {
        Worker worker = workerRepository.findById(request.workerId())
                .orElseThrow(() -> new EntityNotFoundException("Trabajador no encontrado"));

        validateEntryRange(request.clockIn(), request.clockOut(), request.plannedClockOut());

        if (request.clockOut() == null) {
            throw new IllegalArgumentException(
                    "Debes indicar la hora de salida para asignar una jornada manual"
            );
        }

        TimeEntry entry = new TimeEntry();
        entry.setWorker(worker);
        entry.setClockIn(request.clockIn());
        entry.setClockOut(request.clockOut());
        entry.setPlannedClockOut(request.plannedClockOut());
        entry.setWorkSite(request.workSite());
        entry.setAutoClosedAt(null);
        entry.setAutoCloseReason(null);

        return TimeEntryDto.from(timeEntryRepository.save(entry));
    }

    @Transactional
    public TimeEntryDto updateEntry(Long entryId, UpdateTimeEntryRequest request) {
        TimeEntry entry = timeEntryRepository.findById(entryId)
                .orElseThrow(() -> new EntityNotFoundException("Jornada no encontrada"));

        validateEntryRange(request.clockIn(), request.clockOut(), request.plannedClockOut());

        entry.setClockIn(request.clockIn());
        entry.setClockOut(request.clockOut());
        entry.setPlannedClockOut(request.plannedClockOut());
        entry.setWorkSite(request.workSite());

        if (request.clockOut() != null) {
            entry.setAutoClosedAt(null);
            entry.setAutoCloseReason(null);
        }

        return TimeEntryDto.from(timeEntryRepository.save(entry));
    }

    public List<WorkerTimeTrackingStatsDto> getWorkerStats() {
        ZoneId zoneId = BUSINESS_ZONE;
        LocalDate today = LocalDate.now(zoneId);
        Instant now = Instant.now();
        YearMonth currentMonth = YearMonth.from(today);

        List<Worker> workers = workerRepository.findByRoleInAndActiveTrueOrderByFullNameAsc(
                EnumSet.of(Role.WORKER, Role.COMERCIAL)
        );
        Map<Long, Long> absenceDaysByWorker = new HashMap<>();
        Map<Long, Double> productivityByWorker = new HashMap<>();
        Map<Long, Double> completionByWorker = new HashMap<>();
        Map<Long, Double> clockingDisciplineByWorker = new HashMap<>();
        for (Worker worker : workers) {
            absenceDaysByWorker.put(worker.getId(), calculateApprovedNonVacationAbsenceDaysThisYear(worker.getId(), today));
            productivityByWorker.put(worker.getId(), calculateProductivityBasis(worker, now));
            completionByWorker.put(worker.getId(), calculateCompletionBasis(worker));
            clockingDisciplineByWorker.put(worker.getId(), calculateClockingDisciplineScore(worker, today));
        }

        Map<Role, Double> averageAbsenceDaysByRole = averageLongByRole(workers, absenceDaysByWorker);
        Map<Role, Double> averageProductivityByRole = averageDoubleByRole(workers, productivityByWorker);
        Map<Role, Double> averageCompletionByRole = averageDoubleByRole(workers, completionByWorker);
        Map<Role, Double> averageCloseDisciplineByRole = averageDoubleByRole(workers, clockingDisciplineByWorker);

        return workers.stream()
                .map(worker -> buildStats(
                        worker,
                        today,
                        currentMonth,
                        now,
                        averageAbsenceDaysByRole,
                        averageProductivityByRole,
                        averageCompletionByRole,
                        averageCloseDisciplineByRole,
                        absenceDaysByWorker,
                        productivityByWorker,
                        completionByWorker,
                        clockingDisciplineByWorker
                ))
                .toList();
    }

    public WorkerTimeTrackingInsightDto getWorkerInsight(Long workerId) {
        ZoneId zoneId = BUSINESS_ZONE;
        LocalDate today = LocalDate.now(zoneId);
        Instant now = Instant.now();
        YearMonth currentMonth = YearMonth.from(today);

        Worker worker = workerRepository.findById(workerId)
                .orElseThrow(() -> new EntityNotFoundException("Trabajador no encontrado"));

        List<Worker> activeWorkers = workerRepository.findByRoleInAndActiveTrueOrderByFullNameAsc(
                EnumSet.of(Role.WORKER, Role.COMERCIAL)
        );
        Map<Long, Long> absenceDaysByWorker = new HashMap<>();
        Map<Long, Double> productivityByWorker = new HashMap<>();
        Map<Long, Double> completionByWorker = new HashMap<>();
        Map<Long, Double> clockingDisciplineByWorker = new HashMap<>();

        for (Worker item : activeWorkers) {
            absenceDaysByWorker.put(item.getId(), calculateApprovedNonVacationAbsenceDaysThisYear(item.getId(), today));
            productivityByWorker.put(item.getId(), calculateProductivityBasis(item, now));
            completionByWorker.put(item.getId(), calculateCompletionBasis(item));
            clockingDisciplineByWorker.put(item.getId(), calculateClockingDisciplineScore(item, today));
        }

        Map<Role, Double> averageAbsenceDaysByRole = averageLongByRole(activeWorkers, absenceDaysByWorker);
        Map<Role, Double> averageProductivityByRole = averageDoubleByRole(activeWorkers, productivityByWorker);
        Map<Role, Double> averageCompletionByRole = averageDoubleByRole(activeWorkers, completionByWorker);
        Map<Role, Double> averageCloseDisciplineByRole = averageDoubleByRole(activeWorkers, clockingDisciplineByWorker);

        WorkerTimeTrackingStatsDto summary = buildStats(
                worker,
                today,
                currentMonth,
                now,
                averageAbsenceDaysByRole,
                averageProductivityByRole,
                averageCompletionByRole,
                averageCloseDisciplineByRole,
                absenceDaysByWorker,
                productivityByWorker,
                completionByWorker,
                clockingDisciplineByWorker
        );

        Role role = worker.getRole();
        double absenceFactor = invertAgainstAverage(
                absenceDaysByWorker.getOrDefault(workerId, 0L),
                averageAbsenceDaysByRole.getOrDefault(role, 0.0),
                100.0
        );
        double throughputFactor = scoreRelativeToAverage(
                productivityByWorker.getOrDefault(workerId, 0.0),
                averageProductivityByRole.getOrDefault(role, 0.0)
        );
        double signatureFactor = scoreRelativeToAverage(
                completionByWorker.getOrDefault(workerId, 0.0),
                averageCompletionByRole.getOrDefault(role, 0.0)
        );
        double disciplineFactor = clockingDisciplineByWorker.getOrDefault(workerId, 0.0);

        List<WorkerPerformanceFactorDto> factors = List.of(
                new WorkerPerformanceFactorDto(
                        "Ausencias no vacacionales",
                        absenceFactor,
                        summary.approvedNonVacationAbsenceDaysThisYear()
                                + " dia(s) este año frente a una media de "
                                + formatOneDecimal(averageAbsenceDaysByRole.getOrDefault(role, 0.0))
                ),
                new WorkerPerformanceFactorDto(
                        role == Role.COMERCIAL ? "Actividad comercial" : "Partes por hora",
                        throughputFactor,
                        buildProductivityDetail(role, productivityByWorker.getOrDefault(workerId, 0.0))
                ),
                new WorkerPerformanceFactorDto(
                        "Disciplina de fichaje",
                        disciplineFactor,
                        formatOneDecimal(clockingDisciplineByWorker.getOrDefault(workerId, 0.0))
                                + "% mensual. Cierre manual diario como mejor señal; ausencia aprobada como dia justificado"
                ),
                new WorkerPerformanceFactorDto(
                        role == Role.COMERCIAL ? "Seguimiento comercial" : "Firmas completas",
                        signatureFactor,
                        buildCompletionDetail(role, completionByWorker.getOrDefault(workerId, 0.0))
                )
        );

        return new WorkerTimeTrackingInsightDto(
                summary.workerId(),
                summary.workerName(),
                summary.qualityScore(),
                summary.currentlyClockedIn(),
                summary.workedMinutesToday(),
                summary.workedMinutesThisMonth(),
                summary.workedMinutesThisYear(),
                summary.approvedNonVacationAbsenceDaysThisYear(),
                summary.absenceVsAveragePercent(),
                factors,
                buildResolvedWorkOrderRows(workerId, now)
        );
    }

    public TodayClockedWorkersSummaryDto getTodaySummary() {
        ZoneId zoneId = BUSINESS_ZONE;
        LocalDate today = LocalDate.now(zoneId);
        Instant start = today.atStartOfDay(zoneId).toInstant();
        Instant end = today.plusDays(1).atStartOfDay(zoneId).toInstant();

        List<TimeEntry> entries = timeEntryRepository
                .findByClockInGreaterThanEqualAndClockInLessThanOrderByClockInDesc(start, end);

        Map<Long, String> uniqueWorkers = new LinkedHashMap<>();
        for (TimeEntry entry : entries) {
            Worker worker = entry.getWorker();
            if (worker == null || worker.getId() == null) {
                continue;
            }

            String fullName = worker.getFullName();
            if (fullName == null || fullName.isBlank()) {
                fullName = "Trabajador " + worker.getId();
            }
            uniqueWorkers.putIfAbsent(worker.getId(), fullName);
        }

        List<String> workerNames = uniqueWorkers.values().stream()
                .sorted(Comparator.nullsLast(String.CASE_INSENSITIVE_ORDER))
                .toList();

        return new TodayClockedWorkersSummaryDto(workerNames.size(), workerNames);
    }

    public boolean isWorkerOnApprovedLeave(Long workerId, LocalDate date) {
        return leaveRequestRepository.existsByWorkerIdAndStatusAndStartDateLessThanEqualAndEndDateGreaterThanEqual(
                workerId,
                LeaveStatus.APPROVED,
                date,
                date
        );
    }

    public TimeEntry requireEntry(Long entryId) {
        return timeEntryRepository.findById(entryId)
                .orElseThrow(() -> new EntityNotFoundException("Jornada no encontrada"));
    }

    @Transactional
    public TimeEntryDto clockInNowFromWhatsApp(Long workerId, TimeEntryWorkSite workSite) {
        return clockInFromWhatsApp(workerId, LocalTime.now(BUSINESS_ZONE), workSite);
    }

    @Transactional
    public TimeEntryDto clockInFromWhatsApp(Long workerId,
                                            LocalTime reportedTime,
                                            TimeEntryWorkSite workSite) {
        Worker worker = workerRepository.findById(workerId)
                .orElseThrow(() -> new EntityNotFoundException("Trabajador no encontrado"));

        if (reportedTime == null) {
            throw new IllegalArgumentException("Debes indicar una hora valida");
        }

        ZoneId zoneId = BUSINESS_ZONE;
        Instant now = Instant.now();
        Instant reportedClockIn = LocalDate.now(zoneId).atTime(reportedTime).atZone(zoneId).toInstant();
        if (reportedClockIn.isAfter(now)) {
            throw new IllegalArgumentException("La hora indicada no puede estar en el futuro");
        }

        Instant start = LocalDate.now(zoneId).atStartOfDay(zoneId).toInstant();
        Instant end = LocalDate.now(zoneId).plusDays(1).atStartOfDay(zoneId).toInstant();
        boolean hasClockedToday = !timeEntryRepository
                .findByWorkerIdAndClockInGreaterThanEqualAndClockInLessThanOrderByClockInDesc(workerId, start, end)
                .isEmpty();
        if (hasClockedToday) {
            throw new IllegalArgumentException("Ya existe un fichaje registrado hoy");
        }

        timeEntryRepository.findFirstByWorkerIdAndClockOutIsNullOrderByClockInDesc(workerId)
                .ifPresent(entry -> {
                    throw new IllegalArgumentException("El trabajador ya tiene un fichaje abierto");
                });

        TimeEntry entry = new TimeEntry();
        entry.setWorker(worker);
        entry.setClockIn(reportedClockIn);
        entry.setWorkSite(workSite == null ? TimeEntryWorkSite.WORKSHOP : workSite);
        entry.setPlannedClockOut(null);
        entry.setClockInLatitude(null);
        entry.setClockInLongitude(null);
        entry.setCloseReminderSentAt(null);
        entry.setAutoClosedAt(null);
        entry.setAutoCloseReason(null);
        return TimeEntryDto.from(timeEntryRepository.save(entry));
    }

    public List<TimeEntry> findEntriesForDate(Long workerId, LocalDate workDate) {
        ZoneId zoneId = BUSINESS_ZONE;
        Instant start = workDate.atStartOfDay(zoneId).toInstant();
        Instant end = workDate.plusDays(1).atStartOfDay(zoneId).toInstant();
        return timeEntryRepository.findByWorkerIdAndClockInGreaterThanEqualAndClockInLessThanOrderByClockInDesc(
                workerId,
                start,
                end
        );
    }

    @Transactional
    public TimeEntryDto attachClockInLocation(Long entryId, Double latitude, Double longitude) {
        TimeEntry entry = requireEntry(entryId);
        validateOptionalLocation(latitude, longitude);
        entry.setClockInLatitude(latitude);
        entry.setClockInLongitude(longitude);
        return TimeEntryDto.from(timeEntryRepository.save(entry));
    }

    private WorkerTimeTrackingStatsDto buildStats(Worker worker,
                                                  LocalDate today,
                                                  YearMonth currentMonth,
                                                  Instant now,
                                                  Map<Role, Double> averageAbsenceDaysByRole,
                                                  Map<Role, Double> averageProductivityByRole,
                                                  Map<Role, Double> averageCompletionByRole,
                                                  Map<Role, Double> averageCloseDisciplineByRole,
                                                  Map<Long, Long> absenceDaysByWorker,
                                                  Map<Long, Double> productivityByWorker,
                                                  Map<Long, Double> completionByWorker,
                                                  Map<Long, Double> closeDisciplineByWorker) {
        List<TimeEntry> entries = timeEntryRepository.findByWorkerIdOrderByClockInDesc(worker.getId());
        Role role = worker.getRole();

        long workedMinutesToday = 0;
        long workedMinutesThisMonth = 0;
        long workedMinutesThisYear = 0;
        boolean currentlyClockedIn = false;

        for (TimeEntry entry : entries) {
            if (entry.getClockOut() == null) {
                currentlyClockedIn = true;
            }

            long minutes = durationMinutes(entry, now);
            LocalDate workDate = entry.getClockIn().atZone(BUSINESS_ZONE).toLocalDate();

            if (workDate.equals(today)) {
                workedMinutesToday += minutes;
            }
            if (YearMonth.from(workDate).equals(currentMonth)) {
                workedMinutesThisMonth += minutes;
            }
            if (workDate.getYear() == today.getYear()) {
                workedMinutesThisYear += minutes;
            }
        }

        long absenceDays = absenceDaysByWorker.getOrDefault(worker.getId(), 0L);
        double averageAbsenceDays = averageAbsenceDaysByRole.getOrDefault(role, 0.0);
        double absenceVsAveragePercent = averageAbsenceDays <= 0.0
                ? 0.0
                : ((absenceDays - averageAbsenceDays) / averageAbsenceDays) * 100.0;
        double absenceFactor = invertAgainstAverage(absenceDays, averageAbsenceDays, 100.0);
        double throughputFactor = scoreRelativeToAverage(
                productivityByWorker.getOrDefault(worker.getId(), 0.0),
                averageProductivityByRole.getOrDefault(role, 0.0)
        );
        double signatureFactor = scoreRelativeToAverage(
                completionByWorker.getOrDefault(worker.getId(), 0.0),
                averageCompletionByRole.getOrDefault(role, 0.0)
        );
        double qualityScore = closeDisciplineByWorker.getOrDefault(worker.getId(), 0.0);

        return new WorkerTimeTrackingStatsDto(
                worker.getId(),
                worker.getFullName(),
                worker.getRole().name(),
                worker.getPhotoUrl(),
                qualityScore,
                currentlyClockedIn,
                workedMinutesToday,
                workedMinutesThisMonth,
                workedMinutesThisYear,
                absenceDays,
                absenceVsAveragePercent
        );
    }

    private List<WorkerResolvedWorkOrderStatsRowDto> buildResolvedWorkOrderRows(Long workerId, Instant now) {
        List<TimeEntry> entries = timeEntryRepository.findByWorkerIdOrderByClockInDesc(workerId);
        List<WorkOrder> workOrders = workOrderRepository.findByAssignedWorkersIdOrderByCreatedAtDesc(workerId).stream()
                .filter(order -> order.getStatus() == WorkOrderStatus.DONE)
                .toList();
        LocalDate today = LocalDate.now(BUSINESS_ZONE);
        YearMonth month = YearMonth.from(today);

        return List.of(
                buildResolvedWorkOrderRow("Este mes", entries, workOrders, now, workDate -> YearMonth.from(workDate).equals(month)),
                buildResolvedWorkOrderRow("Este año", entries, workOrders, now, workDate -> workDate.getYear() == today.getYear()),
                buildResolvedWorkOrderRow("Historico", entries, workOrders, now, workDate -> true)
        );
    }

    private WorkerResolvedWorkOrderStatsRowDto buildResolvedWorkOrderRow(String label,
                                                                         List<TimeEntry> entries,
                                                                         List<WorkOrder> workOrders,
                                                                         Instant now,
                                                                         java.util.function.Predicate<LocalDate> matchesDate) {
        long workedMinutes = entries.stream()
                .filter(entry -> matchesDate.test(entry.getClockIn().atZone(BUSINESS_ZONE).toLocalDate()))
                .mapToLong(entry -> durationMinutes(entry, now))
                .sum();

        List<WorkOrder> matchingOrders = workOrders.stream()
                .filter(order -> matchesDate.test(resolveWorkOrderCompletedDate(order)))
                .toList();

        double loggedLaborHours = matchingOrders.stream()
                .map(WorkOrder::getLaborHours)
                .filter(java.util.Objects::nonNull)
                .mapToDouble(value -> value.doubleValue())
                .sum();

        double averageWorkedHoursPerOrder = matchingOrders.isEmpty()
                ? 0.0
                : (workedMinutes / 60.0) / matchingOrders.size();

        return new WorkerResolvedWorkOrderStatsRowDto(
                label,
                matchingOrders.size(),
                workedMinutes,
                loggedLaborHours,
                averageWorkedHoursPerOrder
        );
    }

    private LocalDate resolveWorkOrderCompletedDate(WorkOrder workOrder) {
        Instant resolvedAt = workOrder.getClientSignedAt() != null
                ? workOrder.getClientSignedAt()
                : workOrder.getSignedAt() != null
                ? workOrder.getSignedAt()
                : workOrder.getCreatedAt();
        return resolvedAt.atZone(BUSINESS_ZONE).toLocalDate();
    }

    private double calculateThroughputScoreBasis(Long workerId, Instant now) {
        List<WorkOrder> completedOrders = workOrderRepository.findByAssignedWorkersIdOrderByCreatedAtDesc(workerId).stream()
                .filter(order -> order.getStatus() == WorkOrderStatus.DONE)
                .toList();
        long workedMinutes = timeEntryRepository.findByWorkerIdOrderByClockInDesc(workerId).stream()
                .mapToLong(entry -> durationMinutes(entry, now))
                .sum();
        if (workedMinutes <= 0) {
            return 0.0;
        }
        return completedOrders.size() / (workedMinutes / 600.0);
    }

    private double calculateCommercialActivityBasis(Long workerId, Instant now) {
        List<Budget> budgets = budgetRepository.findByCreatedByWorkerIdOrderByCreatedAtDesc(workerId);
        long workedMinutes = timeEntryRepository.findByWorkerIdOrderByClockInDesc(workerId).stream()
                .mapToLong(entry -> durationMinutes(entry, now))
                .sum();
        if (workedMinutes <= 0) {
            return 0.0;
        }
        return budgets.size() / (workedMinutes / 600.0);
    }

    private double calculateSignatureCompletionBasis(Long workerId) {
        List<WorkOrder> completedOrders = workOrderRepository.findByAssignedWorkersIdOrderByCreatedAtDesc(workerId).stream()
                .filter(order -> order.getStatus() == WorkOrderStatus.DONE)
                .toList();
        if (completedOrders.isEmpty()) {
            return 100.0;
        }
        long completeSignatures = completedOrders.stream()
                .filter(order -> order.getSignedAt() != null && order.getClientSignedAt() != null)
                .count();
        return (completeSignatures * 100.0) / completedOrders.size();
    }

    private double calculateCommercialPipelineBasis(Long workerId) {
        List<Budget> budgets = budgetRepository.findByCreatedByWorkerIdOrderByCreatedAtDesc(workerId);
        if (budgets.isEmpty()) {
            return 75.0;
        }

        long progressedBudgets = budgets.stream()
                .filter(budget -> budget.getStatus() != BudgetStatus.DRAFT)
                .count();
        return (progressedBudgets * 100.0) / budgets.size();
    }

    private double calculateClockingDisciplineScore(Worker worker, LocalDate today) {
        YearMonth rankingMonth = today.getDayOfMonth() == 1
                ? YearMonth.from(today.minusMonths(1))
                : YearMonth.from(today);
        LocalDate start = rankingMonth.atDay(1);
        LocalDate endExclusive = today.getDayOfMonth() == 1
                ? rankingMonth.atEndOfMonth().plusDays(1)
                : today;

        if (worker.getContractStartDate() != null && worker.getContractStartDate().isAfter(start)) {
            start = worker.getContractStartDate();
        }
        if (!start.isBefore(endExclusive)) {
            return 0.0;
        }

        ZoneId zoneId = BUSINESS_ZONE;
        double totalScore = 0.0;
        long evaluatedDays = 0;
        for (LocalDate date = start; date.isBefore(endExclusive); date = date.plusDays(1)) {
            if (isWeekend(date)) {
                continue;
            }
            evaluatedDays += 1;

            Instant dayStart = date.atStartOfDay(zoneId).toInstant();
            Instant dayEnd = date.plusDays(1).atStartOfDay(zoneId).toInstant();
            List<TimeEntry> entries = timeEntryRepository
                    .findByWorkerIdAndClockInGreaterThanEqualAndClockInLessThanOrderByClockInDesc(
                            worker.getId(),
                            dayStart,
                            dayEnd
                    );

            if (!entries.isEmpty()) {
                totalScore += scoreClockingDay(entries);
                continue;
            }

            if (isWorkerOnApprovedLeave(worker.getId(), date)) {
                totalScore += 70.0;
            }
        }

        if (evaluatedDays == 0) {
            return 0.0;
        }
        return clampScore(totalScore / evaluatedDays);
    }

    private double scoreClockingDay(List<TimeEntry> entries) {
        boolean allClosed = entries.stream().allMatch(entry -> entry.getClockOut() != null);
        boolean hasManualClose = entries.stream()
                .anyMatch(entry -> entry.getClockOut() != null && entry.getAutoCloseReason() == null);
        boolean hasPlannedAutoClose = entries.stream()
                .anyMatch(entry -> entry.getClockOut() != null
                        && entry.getAutoCloseReason() == TimeEntryAutoCloseReason.PLANNED_END_TIME);
        boolean hasForcedOrOpen = entries.stream()
                .anyMatch(entry -> entry.getClockOut() == null
                        || entry.getAutoCloseReason() == TimeEntryAutoCloseReason.END_OF_DAY_FORCE_CLOSE);

        if (allClosed && hasManualClose && !hasForcedOrOpen) {
            return 100.0;
        }
        if (hasPlannedAutoClose && !hasForcedOrOpen) {
            return 75.0;
        }
        if (allClosed) {
            return 60.0;
        }
        return 35.0;
    }

    private boolean isWeekend(LocalDate date) {
        DayOfWeek dayOfWeek = date.getDayOfWeek();
        return dayOfWeek == DayOfWeek.SATURDAY || dayOfWeek == DayOfWeek.SUNDAY;
    }

    private long calculateApprovedNonVacationAbsenceDaysThisYear(Long workerId, LocalDate today) {
        return leaveRequestRepository.findByWorkerIdAndStatusIn(workerId, Set.of(LeaveStatus.APPROVED))
                .stream()
                .filter(item -> !isVacationReason(item.getReason()))
                .mapToLong(item -> overlapDaysInYear(item, today.getYear()))
                .sum();
    }

    private long overlapDaysInYear(LeaveRequestEntity request, int year) {
        LocalDate yearStart = LocalDate.of(year, 1, 1);
        LocalDate yearEnd = LocalDate.of(year, 12, 31);
        LocalDate start = request.getStartDate().isBefore(yearStart) ? yearStart : request.getStartDate();
        LocalDate end = request.getEndDate().isAfter(yearEnd) ? yearEnd : request.getEndDate();

        if (end.isBefore(start)) {
            return 0;
        }
        return ChronoUnit.DAYS.between(start, end) + 1;
    }

    private long durationMinutes(TimeEntry entry, Instant now) {
        Instant effectiveClockOut = TimeEntryClockOuts.effectiveClockOut(entry);
        Instant end = effectiveClockOut != null ? effectiveClockOut : now;
        if (end.isBefore(entry.getClockIn())) {
            return 0;
        }
        return ChronoUnit.MINUTES.between(entry.getClockIn(), end);
    }

    private void validatePlannedClockOut(Instant clockIn, Instant plannedClockOut) {
        if (plannedClockOut == null) {
            return;
        }

        if (!plannedClockOut.isAfter(clockIn)) {
            throw new IllegalArgumentException("La hora prevista de cierre debe ser posterior al inicio");
        }

        LocalDate clockInDate = ZonedDateTime.ofInstant(clockIn, BUSINESS_ZONE).toLocalDate();
        LocalDate plannedDate = ZonedDateTime.ofInstant(plannedClockOut, BUSINESS_ZONE).toLocalDate();
        if (!plannedDate.equals(clockInDate)) {
            throw new IllegalArgumentException("La hora prevista de cierre debe estar dentro del mismo dia");
        }
    }

    private void validateEntryRange(Instant clockIn, Instant clockOut, Instant plannedClockOut) {
        if (clockOut != null && clockOut.isBefore(clockIn)) {
            throw new IllegalArgumentException("La salida no puede ser anterior a la entrada");
        }
        if (plannedClockOut != null && plannedClockOut.isBefore(clockIn)) {
            throw new IllegalArgumentException("La hora prevista de cierre no puede ser anterior a la entrada");
        }
    }

    private void validateClockInLocation(Double latitude, Double longitude) {
        if (latitude == null || longitude == null) {
            throw new IllegalArgumentException("Debes permitir la ubicacion para fichar");
        }
        validateOptionalLocation(latitude, longitude);
    }

    private void validateOptionalLocation(Double latitude, Double longitude) {
        if (latitude == null || longitude == null) {
            throw new IllegalArgumentException("La ubicacion no es valida");
        }
        if (latitude < -90.0 || latitude > 90.0) {
            throw new IllegalArgumentException("La latitud del fichaje no es valida");
        }
        if (longitude < -180.0 || longitude > 180.0) {
            throw new IllegalArgumentException("La longitud del fichaje no es valida");
        }
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

    private double averageLong(java.util.Collection<Long> values) {
        return values.isEmpty() ? 0.0 : values.stream().mapToLong(Long::longValue).average().orElse(0.0);
    }

    private Map<Role, Double> averageLongByRole(List<Worker> workers, Map<Long, Long> valuesByWorkerId) {
        Map<Role, List<Long>> grouped = new HashMap<>();
        for (Worker worker : workers) {
            grouped.computeIfAbsent(worker.getRole(), ignored -> new ArrayList<>())
                    .add(valuesByWorkerId.getOrDefault(worker.getId(), 0L));
        }

        Map<Role, Double> averages = new HashMap<>();
        for (Map.Entry<Role, List<Long>> entry : grouped.entrySet()) {
            averages.put(entry.getKey(), averageLong(entry.getValue()));
        }
        return averages;
    }

    private double averageDouble(java.util.Collection<Double> values) {
        return values.isEmpty() ? 0.0 : values.stream().mapToDouble(Double::doubleValue).average().orElse(0.0);
    }

    private Map<Role, Double> averageDoubleByRole(List<Worker> workers, Map<Long, Double> valuesByWorkerId) {
        Map<Role, List<Double>> grouped = new HashMap<>();
        for (Worker worker : workers) {
            grouped.computeIfAbsent(worker.getRole(), ignored -> new ArrayList<>())
                    .add(valuesByWorkerId.getOrDefault(worker.getId(), 0.0));
        }

        Map<Role, Double> averages = new HashMap<>();
        for (Map.Entry<Role, List<Double>> entry : grouped.entrySet()) {
            averages.put(entry.getKey(), averageDouble(entry.getValue()));
        }
        return averages;
    }

    private double calculateProductivityBasis(Worker worker, Instant now) {
        if (worker.getRole() == Role.COMERCIAL) {
            return calculateCommercialActivityBasis(worker.getId(), now);
        }
        return calculateThroughputScoreBasis(worker.getId(), now);
    }

    private double calculateCompletionBasis(Worker worker) {
        if (worker.getRole() == Role.COMERCIAL) {
            return calculateCommercialPipelineBasis(worker.getId());
        }
        return calculateSignatureCompletionBasis(worker.getId());
    }

    private double scoreRelativeToAverage(double value, double average) {
        if (average <= 0.0) {
            return value <= 0.0 ? 75.0 : 100.0;
        }
        double ratio = value / average;
        return clampScore(70.0 + ((ratio - 1.0) * 30.0));
    }

    private double invertAgainstAverage(long value, double average, double fallback) {
        if (average <= 0.0) {
            return fallback;
        }
        double ratio = value / average;
        return clampScore(70.0 - ((ratio - 1.0) * 30.0));
    }

    private double clampScore(double value) {
        return Math.max(0.0, Math.min(100.0, value));
    }

    private String formatOneDecimal(double value) {
        return String.format(Locale.US, "%.1f", value);
    }

    private String buildProductivityDetail(Role role, double value) {
        if (role == Role.COMERCIAL) {
            return formatOneDecimal(value) + " presupuestos creados por cada 10 horas fichadas";
        }
        return formatOneDecimal(value) + " partes cerrados por cada 10 horas de trabajo";
    }

    private String buildCompletionDetail(Role role, double value) {
        if (role == Role.COMERCIAL) {
            return formatOneDecimal(value) + "% de presupuestos movidos fuera de borrador";
        }
        return formatOneDecimal(value) + "% de partes cerrados con firma cliente/trabajador";
    }
}
