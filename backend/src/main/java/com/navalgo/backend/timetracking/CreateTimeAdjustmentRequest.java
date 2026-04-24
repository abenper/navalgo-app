package com.navalgo.backend.timetracking;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

import java.time.Instant;
import java.time.LocalDate;

public record CreateTimeAdjustmentRequest(
        Long timeEntryId,
        @NotNull LocalDate workDate,
        Instant requestedClockIn,
        Instant requestedClockOut,
        @NotNull TimeEntryWorkSite workSite,
        @NotBlank @Size(max = 2000) String reason
) {
}