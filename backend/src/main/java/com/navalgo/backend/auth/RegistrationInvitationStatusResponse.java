package com.navalgo.backend.auth;

import java.time.Instant;

public record RegistrationInvitationStatusResponse(
        String fullName,
        String email,
        Instant expiresAt
) {
}
