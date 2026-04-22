package com.navalgo.backend.workorder;

public record MaterialChecklistTemplateItemDto(
        Long id,
        String articleName,
        String reference,
        int sortOrder
) {
}