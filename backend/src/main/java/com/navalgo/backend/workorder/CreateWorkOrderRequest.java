package com.navalgo.backend.workorder;

import jakarta.validation.Valid;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

import java.math.BigDecimal;
import java.util.List;

public record CreateWorkOrderRequest(
        @NotBlank @Size(max = 255) String title,
        @Size(max = 3000) String description,
        @NotNull Long ownerId,
        Long vesselId,
        List<Long> workerIds,
        WorkOrderPriority priority,
        @DecimalMin(value = "0.0", inclusive = true) BigDecimal laborHours,
        Long materialTemplateId,
        @Valid List<EngineHourRequest> engineHours,
        List<String> attachmentUrls,
        @Valid List<AttachmentRequest> attachments
) {
}
