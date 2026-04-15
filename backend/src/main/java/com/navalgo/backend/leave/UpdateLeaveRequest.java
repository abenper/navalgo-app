package com.navalgo.backend.leave;

import jakarta.validation.constraints.Size;

import java.time.LocalDate;

public record UpdateLeaveRequest(
        @Size(min = 1, max = 255) String reason,
        LocalDate startDate,
        LocalDate endDate
) {
}
