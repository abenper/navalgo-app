package com.navalgo.backend.notification;

import java.time.Instant;
import java.util.List;

public record PushDebugStatusDto(
        boolean firebaseEnabled,
        String credentialSource,
        boolean credentialsReadable,
        boolean initializationAttempted,
        boolean firebaseInitialized,
        Instant lastInitializationAttemptAt,
        Instant lastInitializationSuccessAt,
        String lastInitializationError,
        Instant lastSendAttemptAt,
        Instant lastSendSuccessAt,
        String lastSendError,
        int lastRequestedTokenCount,
        int lastInvalidTokenCount,
        int activeTokenCount,
        List<PushDebugPlatformCountDto> activeTokensByPlatform
) {
}
