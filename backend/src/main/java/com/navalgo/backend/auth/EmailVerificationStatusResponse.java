package com.navalgo.backend.auth;

import java.time.Instant;

public record EmailVerificationStatusResponse(
        String fullName,
        String email,
        Instant expiresAt,
        boolean alreadyVerified
) {
}
