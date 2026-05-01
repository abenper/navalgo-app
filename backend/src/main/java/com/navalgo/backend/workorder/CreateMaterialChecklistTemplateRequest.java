package com.navalgo.backend.workorder;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

import java.util.List;

public record CreateMaterialChecklistTemplateRequest(
        @NotBlank @Size(max = 255) String name,
        @Size(max = 1000) String description,
        MaterialChecklistTemplateType templateType,
        Long baseTemplateId,
        @Valid List<MaterialChecklistTemplateItemRequest> items
) {
}
