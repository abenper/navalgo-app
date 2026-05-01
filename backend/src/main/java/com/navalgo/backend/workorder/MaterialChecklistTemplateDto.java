package com.navalgo.backend.workorder;

import java.time.Instant;
import java.util.List;

public record MaterialChecklistTemplateDto(
        Long id,
        String name,
        String description,
        MaterialChecklistTemplateType templateType,
        Long baseTemplateId,
        String baseTemplateName,
        Instant createdAt,
        Instant updatedAt,
        List<MaterialChecklistTemplateItemDto> items,
        int effectiveItemCount,
        MaterialTemplateIncidentAlertDto latestIncident
) {
}
