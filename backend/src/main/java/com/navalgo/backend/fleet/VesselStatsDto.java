package com.navalgo.backend.fleet;

import com.navalgo.backend.workorder.EngineHourSummaryDto;

import java.time.Instant;
import java.util.List;

public record VesselStatsDto(
        Long vesselId,
        int totalWorkOrders,
        int workOrdersWithEngineHours,
        Instant firstRecordedAt,
        Instant lastRecordedAt,
        Integer highestRecordedHour,
        List<EngineHourSummaryDto> latestEngineHours,
        List<VesselEngineHourSeriesDto> engineSeries,
        List<VesselWorkOrderMilestoneDto> workOrderMilestones
) {
}
