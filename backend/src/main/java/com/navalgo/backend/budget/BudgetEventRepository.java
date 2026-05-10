package com.navalgo.backend.budget;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface BudgetEventRepository extends JpaRepository<BudgetEvent, Long> {
    List<BudgetEvent> findByBudgetIdOrderByCreatedAtAscIdAsc(Long budgetId);
    List<BudgetEvent> findByBudgetIdInOrderByBudgetIdAscCreatedAtAscIdAsc(List<Long> budgetIds);
}
