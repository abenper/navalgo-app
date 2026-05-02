package com.navalgo.backend.timetracking;

import org.springframework.data.jpa.repository.JpaRepository;

import java.time.Instant;
import java.util.List;
import java.util.Optional;

public interface TimeEntryRepository extends JpaRepository<TimeEntry, Long> {
    Optional<TimeEntry> findFirstByWorkerIdAndClockOutIsNullOrderByClockInDesc(Long workerId);
    List<TimeEntry> findByWorkerIdOrderByClockInDesc(Long workerId);
    List<TimeEntry> findByWorkerIdOrderByClockInAsc(Long workerId);
    List<TimeEntry> findByWorkerIdAndClockInGreaterThanEqualAndClockInLessThanOrderByClockInDesc(
            Long workerId,
            Instant startInclusive,
            Instant endExclusive
    );
    List<TimeEntry> findByClockInGreaterThanEqualAndClockInLessThanOrderByClockInDesc(
            Instant startInclusive,
            Instant endExclusive
    );
    List<TimeEntry> findByClockOutIsNullOrderByClockInAsc();
    List<TimeEntry> findByClockOutIsNullAndPlannedClockOutLessThanEqualOrderByPlannedClockOutAsc(Instant cutoff);
}
