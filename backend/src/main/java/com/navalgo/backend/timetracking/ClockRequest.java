package com.navalgo.backend.timetracking;

import jakarta.validation.constraints.NotNull;

import java.time.Instant;

public record ClockRequest(
        @NotNull Long workerId,
        TimeEntryWorkSite workSite,
        Instant plannedClockOut,
        Double latitude,
        Double longitude
) {
}
