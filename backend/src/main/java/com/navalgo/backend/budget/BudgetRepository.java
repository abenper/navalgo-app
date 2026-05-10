package com.navalgo.backend.budget;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface BudgetRepository extends JpaRepository<Budget, Long> {
    List<Budget> findAllByOrderByCreatedAtDesc();
    List<Budget> findByOwnerIdOrderByCreatedAtDesc(Long ownerId);
    List<Budget> findByOriginBudgetIdOrderByCreatedAtAsc(Long originBudgetId);
    boolean existsByOwnerId(Long ownerId);
    boolean existsByVesselId(Long vesselId);
}
