package com.navalgo.backend.workorder;

import java.time.Instant;

public record WorkOrderChecklistItemDto(
        Long id,
        Long sourceTemplateItemId,
        String articleName,
        String reference,
        boolean checked,
        Instant checkedAt,
        Long checkedByWorkerId,
        String checkedByWorkerName,
        int sortOrder
) {
}