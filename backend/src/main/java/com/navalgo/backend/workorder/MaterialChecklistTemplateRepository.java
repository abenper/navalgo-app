package com.navalgo.backend.workorder;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface MaterialChecklistTemplateRepository extends JpaRepository<MaterialChecklistTemplate, Long> {
    List<MaterialChecklistTemplate> findAllByOrderByUpdatedAtDesc();
}