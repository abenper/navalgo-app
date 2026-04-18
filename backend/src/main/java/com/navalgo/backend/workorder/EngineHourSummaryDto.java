package com.navalgo.backend.workorder;

import java.time.Instant;

public record EngineHourSummaryDto(String engineLabel, int hours, Instant recordedAt) {
}
