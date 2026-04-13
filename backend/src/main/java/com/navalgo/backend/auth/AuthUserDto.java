package com.navalgo.backend.auth;

import com.navalgo.backend.common.Role;

public record AuthUserDto(
        Long id,
        String name,
        String email,
        Role role
) {
}
