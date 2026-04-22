package com.navalgo.backend.workorder;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

public record CreateMaterialRevisionRequest(
        @NotNull Long checklistItemId,
        @NotBlank @Size(max = 3000) String observations
) {
}