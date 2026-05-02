package com.navalgo.backend.workorder;

import jakarta.validation.Valid;
import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.Size;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.List;

public record UpdateWorkOrderRequest(
        @Size(max = 255) String title,
        @Size(max = 3000) String description,
        Long ownerId,
        Long vesselId,
        List<Long> workerIds,
        WorkOrderPriority priority,
        WorkOrderStatus status,
        LocalDate closeDueDate,
        Boolean clearSignature,
        Boolean clearClientSignature,
        @DecimalMin(value = "0.0", inclusive = true) BigDecimal laborHours,
        Long materialTemplateId,
        Boolean clearMaterialChecklist,
        @Valid List<EngineHourRequest> engineHours,
        List<String> attachmentUrls,
        @Valid List<AttachmentRequest> attachments
) {
}
