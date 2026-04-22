package com.navalgo.backend.workorder;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record MaterialChecklistTemplateItemRequest(
        @NotBlank @Size(max = 255) String articleName,
        @NotBlank @Size(max = 255) String reference,
        Integer sortOrder
) {
}