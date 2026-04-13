package com.navalgo.backend.workorder;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

import java.util.List;

public record CreateWorkOrderRequest(
        @NotBlank String title,
        String description,
        @NotNull Long ownerId,
        Long vesselId,
        List<Long> workerIds,
        WorkOrderPriority priority,
        @Valid List<EngineHourRequest> engineHours,
        List<String> attachmentUrls
) {
}
