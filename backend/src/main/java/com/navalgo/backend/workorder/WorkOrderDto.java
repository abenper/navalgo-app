package com.navalgo.backend.workorder;

import java.time.Instant;
import java.util.List;

public record WorkOrderDto(
        Long id,
        String title,
        String description,
        WorkOrderStatus status,
        WorkOrderPriority priority,
        Long ownerId,
        String ownerName,
        Long vesselId,
        String vesselName,
        List<Long> workerIds,
        List<String> workerNames,
        List<EngineHourRequest> engineHours,
        List<String> attachmentUrls,
        List<AttachmentInfoDto> attachments,
        Instant createdAt
) {
}
