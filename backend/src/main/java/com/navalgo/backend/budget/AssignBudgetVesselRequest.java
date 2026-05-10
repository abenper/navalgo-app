package com.navalgo.backend.budget;

import jakarta.validation.constraints.NotNull;

public record AssignBudgetVesselRequest(
        @NotNull Long vesselId
) {
}
