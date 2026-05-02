package com.navalgo.backend.timetracking;

import java.util.List;

public record WorkerTimeTrackingInsightDto(
        Long workerId,
        String workerName,
        double qualityScore,
        boolean currentlyClockedIn,
        long workedMinutesToday,
        long workedMinutesThisMonth,
        long workedMinutesThisYear,
        long approvedNonVacationAbsenceDaysThisYear,
        double absenceVsAveragePercent,
        List<WorkerPerformanceFactorDto> qualityFactors,
        List<WorkerResolvedWorkOrderStatsRowDto> resolvedWorkOrderStats
) {
}
