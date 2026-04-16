package com.navalgo.backend.company;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record CreateCompanyRequest(
        @NotBlank @Size(max = 255) String name,
        @NotBlank @Size(max = 255) String taxId,
        @Size(max = 255) String phone,
        @Email @Size(max = 255) String email,
        @Size(max = 255) String address
) {
}
