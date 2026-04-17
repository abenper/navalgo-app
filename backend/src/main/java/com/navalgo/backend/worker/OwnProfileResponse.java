package com.navalgo.backend.worker;

import java.time.Instant;

public record OwnProfileResponse(
        WorkerDto worker,
        String token,
        Instant expiresAt
) {
}
