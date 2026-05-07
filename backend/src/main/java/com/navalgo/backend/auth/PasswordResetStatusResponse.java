package com.navalgo.backend.auth;

import java.time.Instant;

public record PasswordResetStatusResponse(
        String fullName,
        String email,
        Instant expiresAt
) {
}
