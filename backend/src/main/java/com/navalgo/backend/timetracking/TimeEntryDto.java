package com.navalgo.backend.timetracking;

import java.time.Instant;

public record TimeEntryDto(
        Long id,
        Long workerId,
        String workerName,
        Instant clockIn,
    Instant clockOut,
    TimeEntryWorkSite workSite
) {
    public static TimeEntryDto from(TimeEntry entry) {
        return new TimeEntryDto(
                entry.getId(),
                entry.getWorker().getId(),
                entry.getWorker().getFullName(),
                entry.getClockIn(),
        entry.getClockOut(),
        entry.getWorkSite()
        );
    }
}
