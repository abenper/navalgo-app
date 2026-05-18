package com.navalgo.backend.timetracking;

public record WorkerTimeTrackingStatsDto(
        Long workerId,
        String workerName,
        String workerRole,
        String photoUrl,
        double qualityScore,
        boolean currentlyClockedIn,
        long workedMinutesToday,
        long workedMinutesThisMonth,
        long workedMinutesThisYear,
        long approvedNonVacationAbsenceDaysThisYear,
        double absenceVsAveragePercent
) {
}
