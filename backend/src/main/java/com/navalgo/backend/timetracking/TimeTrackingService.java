package com.navalgo.backend.timetracking;

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
import java.time.LocalDate;
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

@Service
@Transactional(readOnly = true)
public class TimeTrackingService {

    private final LeaveRequestRepository leaveRequestRepository;
    private final TimeEntryRepository timeEntryRepository;
    private final WorkOrderRepository workOrderRepository;
    private final WorkerRepository workerRepository;

    public TimeTrackingService(LeaveRequestRepository leaveRequestRepository,
                               TimeEntryRepository timeEntryRepository,
                               WorkOrderRepository workOrderRepository,
                               WorkerRepository workerRepository) {
        this.leaveRequestRepository = leaveRequestRepository;
        this.timeEntryRepository = timeEntryRepository;
        this.workOrderRepository = workOrderRepository;
        this.workerRepository = workerRepository;
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
        ZoneId zoneId = ZoneId.systemDefault();
        LocalDate today = LocalDate.now(zoneId);
        Instant now = Instant.now();
        YearMonth currentMonth = YearMonth.from(today);

        List<Worker> workers = workerRepository.findByRoleAndActiveTrueOrderByFullNameAsc(Role.WORKER);
        Map<Long, Long> absenceDaysByWorker = new HashMap<>();
        for (Worker worker : workers) {
            absenceDaysByWorker.put(worker.getId(), calculateApprovedNonVacationAbsenceDaysThisYear(worker.getId(), today));
        }

        double averageAbsenceDays = absenceDaysByWorker.isEmpty()
                ? 0.0
                : absenceDaysByWorker.values().stream().mapToLong(Long::longValue).average().orElse(0.0);

        return workers.stream()
                .map(worker -> buildStats(worker, today, currentMonth, now, averageAbsenceDays, absenceDaysByWorker))
                .toList();
    }

    public WorkerTimeTrackingInsightDto getWorkerInsight(Long workerId) {
        ZoneId zoneId = ZoneId.systemDefault();
        LocalDate today = LocalDate.now(zoneId);
        Instant now = Instant.now();
        YearMonth currentMonth = YearMonth.from(today);

        Worker worker = workerRepository.findById(workerId)
                .orElseThrow(() -> new EntityNotFoundException("Trabajador no encontrado"));

        List<Worker> activeWorkers = workerRepository.findByRoleAndActiveTrueOrderByFullNameAsc(Role.WORKER);
        Map<Long, Long> absenceDaysByWorker = new HashMap<>();
        Map<Long, Double> throughputByWorker = new HashMap<>();
        Map<Long, Double> signatureCompletionByWorker = new HashMap<>();
        Map<Long, Double> closeDisciplineByWorker = new HashMap<>();

        for (Worker item : activeWorkers) {
            absenceDaysByWorker.put(item.getId(), calculateApprovedNonVacationAbsenceDaysThisYear(item.getId(), today));
            throughputByWorker.put(item.getId(), calculateThroughputScoreBasis(item.getId(), now));
            signatureCompletionByWorker.put(item.getId(), calculateSignatureCompletionBasis(item.getId()));
            closeDisciplineByWorker.put(item.getId(), calculateCloseDisciplineBasis(item.getId()));
        }

        double averageAbsenceDays = averageLong(absenceDaysByWorker.values());
        double averageThroughput = averageDouble(throughputByWorker.values());
        double averageSignatureCompletion = averageDouble(signatureCompletionByWorker.values());
        double averageCloseDiscipline = averageDouble(closeDisciplineByWorker.values());

        WorkerTimeTrackingStatsDto summary = buildStats(
                worker,
                today,
                currentMonth,
                now,
                averageAbsenceDays,
                absenceDaysByWorker
        );

        double absenceFactor = invertAgainstAverage(
                absenceDaysByWorker.getOrDefault(workerId, 0L),
                averageAbsenceDays,
                100.0
        );
        double throughputFactor = scoreRelativeToAverage(
                throughputByWorker.getOrDefault(workerId, 0.0),
                averageThroughput
        );
        double signatureFactor = scoreRelativeToAverage(
                signatureCompletionByWorker.getOrDefault(workerId, 0.0),
                averageSignatureCompletion
        );
        double disciplineFactor = scoreRelativeToAverage(
                closeDisciplineByWorker.getOrDefault(workerId, 0.0),
                averageCloseDiscipline
        );

        List<WorkerPerformanceFactorDto> factors = List.of(
                new WorkerPerformanceFactorDto(
                        "Ausencias no vacacionales",
                        absenceFactor,
                        summary.approvedNonVacationAbsenceDaysThisYear()
                                + " dia(s) este año frente a una media de "
                                + formatOneDecimal(averageAbsenceDays)
                ),
                new WorkerPerformanceFactorDto(
                        "Partes por hora",
                        throughputFactor,
                        formatOneDecimal(throughputByWorker.getOrDefault(workerId, 0.0))
                                + " partes cerrados por cada 10 horas de trabajo"
                ),
                new WorkerPerformanceFactorDto(
                        "Cierres sin incidencia",
                        disciplineFactor,
                        formatOneDecimal(closeDisciplineByWorker.getOrDefault(workerId, 0.0))
                                + "% de jornadas sin cierre forzado"
                ),
                new WorkerPerformanceFactorDto(
                        "Firmas completas",
                        signatureFactor,
                        formatOneDecimal(signatureCompletionByWorker.getOrDefault(workerId, 0.0))
                                + "% de partes cerrados con firma cliente/trabajador"
                )
        );

        double qualityScore = factors.stream()
                .mapToDouble(WorkerPerformanceFactorDto::score)
                .average()
                .orElse(0.0);

        return new WorkerTimeTrackingInsightDto(
                summary.workerId(),
                summary.workerName(),
                qualityScore,
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
        ZoneId zoneId = ZoneId.systemDefault();
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

    private WorkerTimeTrackingStatsDto buildStats(Worker worker,
                                                  LocalDate today,
                                                  YearMonth currentMonth,
                                                  Instant now,
                                                  double averageAbsenceDays,
                                                  Map<Long, Long> absenceDaysByWorker) {
        List<TimeEntry> entries = timeEntryRepository.findByWorkerIdOrderByClockInDesc(worker.getId());

        long workedMinutesToday = 0;
        long workedMinutesThisMonth = 0;
        long workedMinutesThisYear = 0;
        boolean currentlyClockedIn = false;

        for (TimeEntry entry : entries) {
            if (entry.getClockOut() == null) {
                currentlyClockedIn = true;
            }

            long minutes = durationMinutes(entry, now);
            LocalDate workDate = entry.getClockIn().atZone(ZoneId.systemDefault()).toLocalDate();

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
        double absenceVsAveragePercent = averageAbsenceDays <= 0.0
                ? 0.0
                : ((absenceDays - averageAbsenceDays) / averageAbsenceDays) * 100.0;

        return new WorkerTimeTrackingStatsDto(
                worker.getId(),
                worker.getFullName(),
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
        LocalDate today = LocalDate.now(ZoneId.systemDefault());
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
                .filter(entry -> matchesDate.test(entry.getClockIn().atZone(ZoneId.systemDefault()).toLocalDate()))
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
        return resolvedAt.atZone(ZoneId.systemDefault()).toLocalDate();
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

    private double calculateCloseDisciplineBasis(Long workerId) {
        List<TimeEntry> entries = timeEntryRepository.findByWorkerIdOrderByClockInDesc(workerId);
        List<TimeEntry> closedEntries = entries.stream()
                .filter(entry -> entry.getClockOut() != null)
                .toList();
        if (closedEntries.isEmpty()) {
            return 100.0;
        }
        long healthyClosures = closedEntries.stream()
                .filter(entry -> entry.getAutoCloseReason() != TimeEntryAutoCloseReason.END_OF_DAY_FORCE_CLOSE)
                .count();
        return (healthyClosures * 100.0) / closedEntries.size();
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
        Instant end = entry.getClockOut() != null ? entry.getClockOut() : now;
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

        LocalDate clockInDate = ZonedDateTime.ofInstant(clockIn, ZoneId.systemDefault()).toLocalDate();
        LocalDate plannedDate = ZonedDateTime.ofInstant(plannedClockOut, ZoneId.systemDefault()).toLocalDate();
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

    private double averageDouble(java.util.Collection<Double> values) {
        return values.isEmpty() ? 0.0 : values.stream().mapToDouble(Double::doubleValue).average().orElse(0.0);
    }

    private double scoreRelativeToAverage(double value, double average) {
        if (average <= 0.0) {
            return 100.0;
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
}
