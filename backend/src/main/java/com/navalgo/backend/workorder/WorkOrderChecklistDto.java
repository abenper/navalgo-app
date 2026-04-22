package com.navalgo.backend.workorder;

import java.time.Instant;
import java.util.List;

public record WorkOrderChecklistDto(
        Long id,
        Long sourceTemplateId,
        String sourceTemplateName,
        Instant assignedAt,
        List<WorkOrderChecklistItemDto> items
) {
}