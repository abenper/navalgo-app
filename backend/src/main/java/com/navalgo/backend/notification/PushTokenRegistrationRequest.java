package com.navalgo.backend.notification;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record PushTokenRegistrationRequest(
        @NotBlank @Size(max = 4096) String token,
        @NotBlank @Size(max = 40) String platform
) {
}