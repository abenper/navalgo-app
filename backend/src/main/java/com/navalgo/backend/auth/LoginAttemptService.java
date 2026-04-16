package com.navalgo.backend.auth;

import org.springframework.stereotype.Service;

import java.time.Duration;
import java.time.Instant;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

@Service
public class LoginAttemptService {

    private static final int MAX_ATTEMPTS = 5;
    private static final Duration WINDOW = Duration.ofMinutes(10);

    private final Map<String, AttemptWindow> attempts = new ConcurrentHashMap<>();

    public void checkAllowed(String email, String clientIp) {
        String key = buildKey(email, clientIp);
        AttemptWindow window = attempts.get(key);
        if (window == null) {
            return;
        }

        if (window.expiresAt().isBefore(Instant.now())) {
            attempts.remove(key);
            return;
        }

        if (window.failures() >= MAX_ATTEMPTS) {
            throw new RateLimitExceededException("Demasiados intentos de acceso. Intentalo de nuevo en unos minutos.");
        }
    }

    public void recordFailure(String email, String clientIp) {
        String key = buildKey(email, clientIp);
        attempts.compute(key, (ignoredKey, existing) -> {
            Instant now = Instant.now();
            if (existing == null || existing.expiresAt().isBefore(now)) {
                return new AttemptWindow(1, now.plus(WINDOW));
            }
            return new AttemptWindow(existing.failures() + 1, existing.expiresAt());
        });
    }

    public void recordSuccess(String email, String clientIp) {
        attempts.remove(buildKey(email, clientIp));
    }

    private String buildKey(String email, String clientIp) {
        String normalizedEmail = email == null ? "na" : email.trim().toLowerCase();
        String normalizedIp = clientIp == null ? "na" : clientIp.trim();
        return normalizedEmail + "|" + normalizedIp;
    }

    private record AttemptWindow(int failures, Instant expiresAt) {
    }
}