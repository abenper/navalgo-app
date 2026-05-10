package com.navalgo.backend.auth;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record ClientSignupRequest(
        @NotBlank @Size(max = 255) String fullName,
        @NotBlank @Email @Size(max = 255) String email,
        @NotBlank @Size(min = 12, max = 128) String password,
        @Size(max = 255) String phone,
        @Size(max = 255) String vesselName,
        @Size(max = 255) String vesselRegistrationNumber,
        @Size(max = 255) String vesselModel
) {
}
