package com.navalgo.backend.timetracking;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;

public interface TimeEntryRepository extends JpaRepository<TimeEntry, Long> {
    Optional<TimeEntry> findFirstByWorkerIdAndClockOutIsNullOrderByClockInDesc(Long workerId);
    List<TimeEntry> findByWorkerIdOrderByClockInDesc(Long workerId);
}
