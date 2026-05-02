package com.navalgo.backend.notification;

import java.time.Instant;

public record PushDebugTokenDto(
        Long workerId,
        String workerName,
        String workerEmail,
        String platform,
        boolean active,
        String maskedToken,
        Instant createdAt,
        Instant lastSeenAt
) {
}
