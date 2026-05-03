package com.navalgo.backend.fleet;

import com.navalgo.backend.workorder.EngineHourSummaryDto;

import java.time.Instant;
import java.util.List;

public record VesselWorkOrderMilestoneDto(
        Long workOrderId,
        String workOrderTitle,
        String workOrderStatus,
        Instant recordedAt,
        Integer maxHours,
        List<EngineHourSummaryDto> engineHours
) {
}
