package com.navalgo.backend.auth;

import org.springframework.stereotype.Service;

import java.time.Duration;
import java.time.Instant;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

@Service
public class LoginAttemptService {

    private static final int MAX_LOGIN_ATTEMPTS_PER_IDENTITY = 5;
    private static final int MAX_LOGIN_ATTEMPTS_PER_IP = 20;
    private static final Duration LOGIN_WINDOW = Duration.ofMinutes(10);
    private static final int MAX_PASSWORD_RESET_ATTEMPTS = 3;
    private static final Duration PASSWORD_RESET_WINDOW = Duration.ofMinutes(15);
    private static final int MAX_SIGNUP_ATTEMPTS = 3;
    private static final Duration SIGNUP_WINDOW = Duration.ofMinutes(30);

    private final Map<String, AttemptWindow> attempts = new ConcurrentHashMap<>();

    public void checkAllowed(String email, String clientIp) {
        checkWindow("login:identity", email, clientIp, MAX_LOGIN_ATTEMPTS_PER_IDENTITY, LOGIN_WINDOW,
                "Demasiados intentos de acceso. Intentalo de nuevo en unos minutos.");
        checkWindow("login:ip", null, clientIp, MAX_LOGIN_ATTEMPTS_PER_IP, LOGIN_WINDOW,
                "Se ha superado el limite de intentos desde esta conexion. Intentalo de nuevo en unos minutos.");
    }

    public void recordFailure(String email, String clientIp) {
        incrementWindow("login:identity", email, clientIp, LOGIN_WINDOW);
        incrementWindow("login:ip", null, clientIp, LOGIN_WINDOW);
    }

    public void recordSuccess(String email, String clientIp) {
        attempts.remove(buildKey("login:identity", email, clientIp));
    }

    public void checkPasswordResetAllowed(String email, String clientIp) {
        checkWindow("password-reset", email, clientIp, MAX_PASSWORD_RESET_ATTEMPTS, PASSWORD_RESET_WINDOW,
                "Has solicitado demasiados cambios de contrasena. Espera unos minutos antes de volver a intentarlo.");
    }

    public void recordPasswordResetAttempt(String email, String clientIp) {
        incrementWindow("password-reset", email, clientIp, PASSWORD_RESET_WINDOW);
    }

    public void checkSignupAllowed(String email, String clientIp) {
        checkWindow("client-signup", email, clientIp, MAX_SIGNUP_ATTEMPTS, SIGNUP_WINDOW,
                "Demasiados intentos de alta desde este correo o conexion. Espera antes de volver a intentarlo.");
    }

    public void recordSignupAttempt(String email, String clientIp) {
        incrementWindow("client-signup", email, clientIp, SIGNUP_WINDOW);
    }

    private void checkWindow(String scope,
                             String identity,
                             String clientIp,
                             int maxAttempts,
                             Duration windowDuration,
                             String message) {
        String key = buildKey(scope, identity, clientIp);
        AttemptWindow window = attempts.get(key);
        if (window == null) {
            return;
        }

        if (window.expiresAt().isBefore(Instant.now())) {
            attempts.remove(key);
            return;
        }

        if (window.failures() >= maxAttempts) {
            throw new RateLimitExceededException(message);
        }
    }

    private void incrementWindow(String scope, String identity, String clientIp, Duration windowDuration) {
        String key = buildKey(scope, identity, clientIp);
        attempts.compute(key, (ignoredKey, existing) -> {
            Instant now = Instant.now();
            if (existing == null || existing.expiresAt().isBefore(now)) {
                return new AttemptWindow(1, now.plus(windowDuration));
            }
            return new AttemptWindow(existing.failures() + 1, existing.expiresAt());
        });
    }

    private String buildKey(String scope, String identity, String clientIp) {
        String normalizedScope = scope == null ? "na" : scope.trim().toLowerCase();
        String normalizedEmail = identity == null ? "na" : identity.trim().toLowerCase();
        String normalizedIp = clientIp == null ? "na" : clientIp.trim();
        return normalizedScope + "|" + normalizedEmail + "|" + normalizedIp;
    }

    private record AttemptWindow(int failures, Instant expiresAt) {
    }
}
