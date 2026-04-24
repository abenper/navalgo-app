package com.navalgo.backend.notification;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record PushTokenUnregistrationRequest(
        @NotBlank @Size(max = 4096) String token
) {
}