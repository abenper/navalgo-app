package com.navalgo.backend.workorder;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
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
        BigDecimal laborHours,
        WorkOrderChecklistDto materialChecklist,
        List<MaterialRevisionRequestDto> materialRevisionRequests,
        List<EngineHourRequest> engineHours,
        List<String> attachmentUrls,
        List<AttachmentInfoDto> attachments,
        LocalDate closeDueDate,
        Instant createdAt,
        String signatureUrl,
        String clientSignatureUrl,
        Instant signedAt,
        Instant clientSignedAt,
        Long signedByWorkerId,
        String signedByWorkerName
) {
}
