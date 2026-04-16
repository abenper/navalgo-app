package com.navalgo.backend.leave;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

import java.time.LocalDate;

public record CreateLeaveRequest(
        @NotNull Long workerId,
        @NotBlank @Size(max = 255) String reason,
        @NotNull LocalDate startDate,
        @NotNull LocalDate endDate
) {
}
