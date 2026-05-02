package com.navalgo.backend.timetracking;

import com.navalgo.backend.common.Role;
import com.navalgo.backend.leave.LeaveRequestEntity;
import com.navalgo.backend.leave.LeaveRequestRepository;
import com.navalgo.backend.leave.LeaveStatus;
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
    private final WorkerRepository workerRepository;

    public TimeTrackingService(LeaveRequestRepository leaveRequestRepository,
                               TimeEntryRepository timeEntryRepository,
                               WorkerRepository workerRepository) {
        this.leaveRequestRepository = leaveRequestRepository;
        this.timeEntryRepository = timeEntryRepository;
        this.workerRepository = workerRepository;
    }

    @Transactional
    public TimeEntryDto clockIn(Long workerId, TimeEntryWorkSite workSite, Instant plannedClockOut) {
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

        TimeEntry entry = new TimeEntry();
        entry.setWorker(worker);
        entry.setClockIn(now);
        entry.setWorkSite(workSite);
        entry.setPlannedClockOut(plannedClockOut);

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
