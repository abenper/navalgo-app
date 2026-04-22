package com.navalgo.backend.workorder;

import java.time.Instant;
import java.util.List;

public record MaterialChecklistTemplateDto(
        Long id,
        String name,
        String description,
        Instant createdAt,
        Instant updatedAt,
        List<MaterialChecklistTemplateItemDto> items,
        MaterialTemplateIncidentAlertDto latestIncident
) {
}