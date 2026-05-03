package com.navalgo.backend.fleet;

import java.util.List;

public record VesselEngineHourSeriesDto(
        String engineLabel,
        List<VesselEngineHourPointDto> points
) {
}
