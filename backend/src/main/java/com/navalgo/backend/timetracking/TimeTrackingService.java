package com.navalgo.backend.timetracking;

import com.navalgo.backend.worker.Worker;
import com.navalgo.backend.worker.WorkerRepository;
import jakarta.persistence.EntityNotFoundException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

@Service
@Transactional(readOnly = true)
public class TimeTrackingService {

    private final TimeEntryRepository timeEntryRepository;
    private final WorkerRepository workerRepository;

    public TimeTrackingService(TimeEntryRepository timeEntryRepository,
                               WorkerRepository workerRepository) {
        this.timeEntryRepository = timeEntryRepository;
        this.workerRepository = workerRepository;
    }

    @Transactional
    public TimeEntryDto clockIn(Long workerId, TimeEntryWorkSite workSite) {
        Worker worker = workerRepository.findById(workerId)
                .orElseThrow(() -> new EntityNotFoundException("Trabajador no encontrado"));

        if (workSite == null) {
            throw new IllegalArgumentException("Debes indicar si el fichaje es en taller o en viaje");
        }

        timeEntryRepository.findFirstByWorkerIdAndClockOutIsNullOrderByClockInDesc(workerId)
                .ifPresent(entry -> {
                    throw new IllegalArgumentException("El trabajador ya tiene un fichaje abierto");
                });

        TimeEntry entry = new TimeEntry();
        entry.setWorker(worker);
        entry.setClockIn(Instant.now());
        entry.setWorkSite(workSite);

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
}
