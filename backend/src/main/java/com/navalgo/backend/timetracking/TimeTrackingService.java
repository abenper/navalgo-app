package com.navalgo.backend.timetracking;

import com.navalgo.backend.worker.Worker;
import com.navalgo.backend.worker.WorkerRepository;
import jakarta.persistence.EntityNotFoundException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.List;

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
    public TimeEntryDto clockIn(Long workerId) {
        Worker worker = workerRepository.findById(workerId)
                .orElseThrow(() -> new EntityNotFoundException("Trabajador no encontrado"));

        timeEntryRepository.findFirstByWorkerIdAndClockOutIsNullOrderByClockInDesc(workerId)
                .ifPresent(entry -> {
                    throw new IllegalArgumentException("El trabajador ya tiene un fichaje abierto");
                });

        TimeEntry entry = new TimeEntry();
        entry.setWorker(worker);
        entry.setClockIn(Instant.now());

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
}
