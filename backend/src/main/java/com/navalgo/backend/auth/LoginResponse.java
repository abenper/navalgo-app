package com.navalgo.backend.auth;

public record LoginResponse(
        AuthUserDto user,
        String token
) {
}
