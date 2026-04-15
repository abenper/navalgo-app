package com.navalgo.backend.fleet;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

public record UpdateOwnerRequest(
        @NotNull OwnerType type,
        @NotBlank String displayName,
        @NotBlank String documentId,
        String phone,
        String email,
        Long companyId
) {
}
