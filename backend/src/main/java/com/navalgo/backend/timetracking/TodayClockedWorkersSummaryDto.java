package com.navalgo.backend.timetracking;

import java.util.List;

public record TodayClockedWorkersSummaryDto(
        long clockedWorkersCount,
        List<String> workerNames
) {
}