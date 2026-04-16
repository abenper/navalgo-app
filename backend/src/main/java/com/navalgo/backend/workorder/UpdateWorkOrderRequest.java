package com.navalgo.backend.workorder;

import jakarta.validation.Valid;
import jakarta.validation.constraints.Size;

import java.util.List;

public record UpdateWorkOrderRequest(
        @Size(max = 255) String title,
        @Size(max = 3000) String description,
        Long ownerId,
        Long vesselId,
        List<Long> workerIds,
        WorkOrderPriority priority,
        WorkOrderStatus status,
        Boolean clearSignature,
        @Valid List<EngineHourRequest> engineHours,
        List<String> attachmentUrls,
        @Valid List<AttachmentRequest> attachments
) {
}
