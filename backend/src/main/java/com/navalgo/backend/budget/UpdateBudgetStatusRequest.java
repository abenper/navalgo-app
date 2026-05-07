package com.navalgo.backend.budget;

import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

public record UpdateBudgetStatusRequest(
        @NotNull BudgetStatus status,
        @Size(max = 2000) String clientObservations
) {
}
