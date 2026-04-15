package com.navalgo.backend.timetracking;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;
import java.util.Optional;

public interface TimeEntryRepository extends JpaRepository<TimeEntry, Long> {
    Optional<TimeEntry> findFirstByWorkerIdAndClockOutIsNullOrderByClockInDesc(Long workerId);
    List<TimeEntry> findByWorkerIdOrderByClockInDesc(Long workerId);

    @Query(value = "SELECT COUNT(DISTINCT clock_in::date) FROM time_entries WHERE worker_id = :workerId", nativeQuery = true)
    long countDistinctWorkedDays(@Param("workerId") Long workerId);
}
