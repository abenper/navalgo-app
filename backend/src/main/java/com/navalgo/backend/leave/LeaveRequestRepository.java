package com.navalgo.backend.leave;

import org.springframework.data.jpa.repository.JpaRepository;

import java.time.LocalDate;
import java.util.List;
import java.util.Set;

public interface LeaveRequestRepository extends JpaRepository<LeaveRequestEntity, Long> {
    List<LeaveRequestEntity> findByWorkerIdOrderByStartDateDesc(Long workerId);
    List<LeaveRequestEntity> findByStatusNotOrderByStartDateDesc(LeaveStatus status);
    List<LeaveRequestEntity> findByWorkerIdAndStatusNotOrderByStartDateDesc(Long workerId, LeaveStatus status);
    List<LeaveRequestEntity> findByWorkerIdAndStatusIn(Long workerId, Set<LeaveStatus> statuses);
    boolean existsByWorkerIdAndStatusAndStartDateLessThanEqualAndEndDateGreaterThanEqual(
            Long workerId,
            LeaveStatus status,
            LocalDate endDateInclusive,
            LocalDate startDateInclusive
    );
}
