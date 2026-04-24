package com.navalgo.backend.timetracking;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface TimeAdjustmentRequestRepository extends JpaRepository<TimeAdjustmentRequest, Long> {
    List<TimeAdjustmentRequest> findAllByOrderByCreatedAtDesc();
    List<TimeAdjustmentRequest> findByWorkerIdOrderByCreatedAtDesc(Long workerId);
    List<TimeAdjustmentRequest> findByStatusOrderByCreatedAtDesc(TimeAdjustmentRequestStatus status);
}