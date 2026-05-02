package com.navalgo.backend.timetracking;

import jakarta.validation.constraints.NotNull;

import java.time.Instant;

public record UpdateTimeEntryRequest(
        @NotNull Instant clockIn,
        Instant clockOut,
        Instant plannedClockOut,
        @NotNull TimeEntryWorkSite workSite
) {
}
