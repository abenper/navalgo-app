package com.navalgo.backend.timetracking;

public record WorkerPerformanceFactorDto(
        String label,
        double score,
        String detail
) {
}
