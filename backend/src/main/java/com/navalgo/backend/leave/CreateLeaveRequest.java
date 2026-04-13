package com.navalgo.backend.leave;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

import java.time.LocalDate;

public record CreateLeaveRequest(
        @NotNull Long workerId,
        @NotBlank String reason,
        @NotNull LocalDate startDate,
        @NotNull LocalDate endDate
) {
}
