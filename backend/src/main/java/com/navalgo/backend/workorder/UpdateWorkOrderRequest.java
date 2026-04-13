package com.navalgo.backend.workorder;

import jakarta.validation.Valid;

import java.util.List;

public record UpdateWorkOrderRequest(
        String title,
        String description,
        Long ownerId,
        Long vesselId,
        List<Long> workerIds,
        WorkOrderPriority priority,
        WorkOrderStatus status,
        @Valid List<EngineHourRequest> engineHours,
        List<String> attachmentUrls
) {
}
