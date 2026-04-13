package com.navalgo.backend.company;

import jakarta.validation.constraints.NotBlank;

public record CreateCompanyRequest(
        @NotBlank String name,
        @NotBlank String taxId,
        String phone,
        String email,
        String address
) {
}
