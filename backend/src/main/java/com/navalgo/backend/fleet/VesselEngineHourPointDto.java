package com.navalgo.backend.fleet;

import java.time.Instant;

public record VesselEngineHourPointDto(
        Long workOrderId,
        String workOrderTitle,
        String workOrderStatus,
        int hours,
        Instant recordedAt
) {
}
