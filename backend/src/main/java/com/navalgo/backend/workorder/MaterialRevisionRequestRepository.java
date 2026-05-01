package com.navalgo.backend.workorder;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Collection;
import java.util.Optional;

public interface MaterialRevisionRequestRepository extends JpaRepository<MaterialRevisionRequest, Long> {
    Optional<MaterialRevisionRequest> findFirstByProductIdInOrderByCreatedAtDesc(Collection<Long> productIds);
}
