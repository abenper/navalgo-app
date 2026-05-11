package com.navalgo.backend.workorder;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.Collection;
import java.util.Optional;

public interface MaterialRevisionRequestRepository extends JpaRepository<MaterialRevisionRequest, Long> {
    Optional<MaterialRevisionRequest> findFirstByProductIdInOrderByCreatedAtDesc(Collection<Long> productIds);
    boolean existsByRequestedByWorkerId(Long workerId);

    @Modifying
    @Query("UPDATE MaterialRevisionRequest request SET request.reviewedByWorker = null WHERE request.reviewedByWorker.id = :workerId")
    void clearReviewedByWorker(@Param("workerId") Long workerId);
}
