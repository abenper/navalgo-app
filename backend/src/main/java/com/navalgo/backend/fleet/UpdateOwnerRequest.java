package com.navalgo.backend.fleet;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

public record UpdateOwnerRequest(
        @NotNull OwnerType type,
        @NotBlank @Size(max = 255) String displayName,
        @NotBlank @Size(max = 255) String documentId,
        @Size(max = 255) String phone,
        @Email @Size(max = 255) String email,
        Long companyId
) {
}
