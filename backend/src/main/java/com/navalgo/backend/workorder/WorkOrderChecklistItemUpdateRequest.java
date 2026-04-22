package com.navalgo.backend.workorder;

import jakarta.validation.constraints.NotNull;

public record WorkOrderChecklistItemUpdateRequest(
        @NotNull Long itemId,
        @NotNull Boolean checked
) {
}