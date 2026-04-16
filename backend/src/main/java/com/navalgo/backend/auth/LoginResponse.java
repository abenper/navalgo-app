package com.navalgo.backend.auth;

import java.time.Instant;

public record LoginResponse(
        AuthUserDto user,
                String token,
                String tokenType,
                Instant expiresAt
) {

        public LoginResponse(AuthUserDto user, String token) {
                this(user, token, "Bearer", null);
        }
}
