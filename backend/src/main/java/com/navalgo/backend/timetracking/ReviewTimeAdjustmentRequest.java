package com.navalgo.backend.timetracking;

import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

public record ReviewTimeAdjustmentRequest(
        @NotNull TimeAdjustmentRequestStatus status,
        @Size(max = 1000) String adminComment
) {
}