package com.navalgo.backend.workorder;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;

public interface MaterialRevisionRequestRepository extends JpaRepository<MaterialRevisionRequest, Long> {
    Optional<MaterialRevisionRequest> findTopBySourceTemplateIdOrderByCreatedAtDesc(Long sourceTemplateId);
}