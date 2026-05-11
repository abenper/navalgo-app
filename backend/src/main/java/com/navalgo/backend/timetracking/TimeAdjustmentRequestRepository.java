package com.navalgo.backend.timetracking;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;

public interface TimeAdjustmentRequestRepository extends JpaRepository<TimeAdjustmentRequest, Long> {
    List<TimeAdjustmentRequest> findAllByOrderByCreatedAtDesc();
    List<TimeAdjustmentRequest> findByWorkerIdOrderByCreatedAtDesc(Long workerId);
    List<TimeAdjustmentRequest> findByStatusOrderByCreatedAtDesc(TimeAdjustmentRequestStatus status);
    void deleteByWorkerId(Long workerId);

    @Modifying
    @Query("UPDATE TimeAdjustmentRequest request SET request.reviewedByWorker = null WHERE request.reviewedByWorker.id = :workerId")
    void clearReviewedByWorker(@Param("workerId") Long workerId);
}
