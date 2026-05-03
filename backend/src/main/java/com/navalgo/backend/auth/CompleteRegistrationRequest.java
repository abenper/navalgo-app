package com.navalgo.backend.auth;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record CompleteRegistrationRequest(
        @NotBlank String token,
        @NotBlank @Size(min = 12, max = 128) String password
) {
}
