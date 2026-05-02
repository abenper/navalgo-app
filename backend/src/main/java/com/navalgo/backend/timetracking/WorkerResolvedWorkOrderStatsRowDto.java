package com.navalgo.backend.timetracking;

public record WorkerResolvedWorkOrderStatsRowDto(
        String label,
        long completedWorkOrders,
        long workedMinutes,
        double loggedLaborHours,
        double averageWorkedHoursPerOrder
) {
}
