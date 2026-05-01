package com.navalgo.backend.workorder;

public record MaterialChecklistTemplateItemDto(
        Long id,
        Long productId,
        String articleName,
        String reference,
        int sortOrder
) {
}
