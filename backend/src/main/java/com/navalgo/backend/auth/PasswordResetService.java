package com.navalgo.backend.auth;

import com.navalgo.backend.notification.ResendEmailService;
import com.navalgo.backend.worker.Worker;
import com.navalgo.backend.worker.WorkerRepository;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.util.UriComponentsBuilder;

import java.time.Instant;

@Service
@Transactional(readOnly = true)
public class PasswordResetService {

    private static final String SCREEN_QUERY_PARAM = "screen";
    private static final String RESET_PASSWORD_SCREEN = "reset-password";

    private final WorkerRepository workerRepository;
    private final PasswordResetTokenRepository passwordResetTokenRepository;
    private final SecureTokenSupport secureTokenSupport;
    private final PasswordEncoder passwordEncoder;
    private final RefreshTokenService refreshTokenService;
    private final ResendEmailService resendEmailService;
    private final LoginAttemptService loginAttemptService;
    private final String frontendBaseUrl;
    private final long passwordResetTtlMinutes;

    public PasswordResetService(WorkerRepository workerRepository,
                                PasswordResetTokenRepository passwordResetTokenRepository,
                                SecureTokenSupport secureTokenSupport,
                                PasswordEncoder passwordEncoder,
                                RefreshTokenService refreshTokenService,
                                ResendEmailService resendEmailService,
                                LoginAttemptService loginAttemptService,
                                @Value("${app.frontend.base-url:https://app.naval-go.com}") String frontendBaseUrl,
                                @Value("${app.auth.password-reset-ttl-minutes:30}") long passwordResetTtlMinutes) {
        this.workerRepository = workerRepository;
        this.passwordResetTokenRepository = passwordResetTokenRepository;
        this.secureTokenSupport = secureTokenSupport;
        this.passwordEncoder = passwordEncoder;
        this.refreshTokenService = refreshTokenService;
        this.resendEmailService = resendEmailService;
        this.loginAttemptService = loginAttemptService;
        this.frontendBaseUrl = frontendBaseUrl;
        this.passwordResetTtlMinutes = passwordResetTtlMinutes;
    }

    @Transactional
    public void requestReset(String email, String clientIp) {
        if (email == null || email.isBlank()) {
            return;
        }

        String normalizedEmail = email.trim().toLowerCase();
        loginAttemptService.checkPasswordResetAllowed(normalizedEmail, clientIp);
        loginAttemptService.recordPasswordResetAttempt(normalizedEmail, clientIp);

        workerRepository.findByEmailIgnoreCase(normalizedEmail).ifPresent(worker -> {
            passwordResetTokenRepository.deleteByWorker_Id(worker.getId());
            String rawToken = secureTokenSupport.generateUrlSafeToken(32);
            PasswordResetToken token = new PasswordResetToken();
            token.setWorker(worker);
            token.setTokenHash(secureTokenSupport.sha256Hex(rawToken));
            token.setCreatedAt(Instant.now());
            token.setExpiresAt(Instant.now().plusSeconds(passwordResetTtlMinutes * 60));
            passwordResetTokenRepository.save(token);

            resendEmailService.sendPasswordReset(
                    worker.getFullName(),
                    worker.getEmail(),
                    buildPublicUrl(rawToken)
            );
        });
    }

    public PasswordResetStatusResponse getResetStatus(String rawToken) {
        PasswordResetToken token = requireValidResetToken(rawToken);
        Worker worker = token.getWorker();
        return new PasswordResetStatusResponse(
                worker.getFullName(),
                worker.getEmail(),
                token.getExpiresAt()
        );
    }

    @Transactional
    public void completeReset(CompletePasswordResetRequest request) {
        String password = request.password() == null ? "" : request.password().trim();
        if (!isStrongPassword(password)) {
            throw new IllegalArgumentException("La contrasena debe tener minimo 12 caracteres e incluir mayuscula, minuscula, numero y simbolo");
        }

        PasswordResetToken token = requireValidResetToken(request.token());
        Worker worker = token.getWorker();
        worker.setPasswordHash(passwordEncoder.encode(password));
        worker.setMustChangePassword(false);
        workerRepository.save(worker);
        refreshTokenService.revokeAllForWorker(worker.getId());

        token.setConsumedAt(Instant.now());
        passwordResetTokenRepository.save(token);
        passwordResetTokenRepository.deleteByWorker_Id(worker.getId());
    }

    private PasswordResetToken requireValidResetToken(String rawToken) {
        if (rawToken == null || rawToken.isBlank()) {
            throw new IllegalArgumentException("El enlace para cambiar la contrasena no es valido o ha caducado");
        }

        PasswordResetToken token = passwordResetTokenRepository
                .findByTokenHash(secureTokenSupport.sha256Hex(rawToken))
                .orElseThrow(() -> new IllegalArgumentException("El enlace para cambiar la contrasena no es valido o ha caducado"));

        if (token.getConsumedAt() != null || token.getExpiresAt().isBefore(Instant.now())) {
            throw new IllegalArgumentException("El enlace para cambiar la contrasena no es valido o ha caducado");
        }
        return token;
    }

    private String buildPublicUrl(String token) {
        return UriComponentsBuilder.fromUriString(frontendBaseUrl)
                .replaceQuery(null)
                .queryParam(SCREEN_QUERY_PARAM, RESET_PASSWORD_SCREEN)
                .queryParam("token", token)
                .build(true)
                .toUriString();
    }

    private boolean isStrongPassword(String password) {
        if (password == null || password.length() < 12) {
            return false;
        }
        boolean hasUpper = false;
        boolean hasLower = false;
        boolean hasDigit = false;
        boolean hasSymbol = false;
        for (char current : password.toCharArray()) {
            if (Character.isUpperCase(current)) {
                hasUpper = true;
            } else if (Character.isLowerCase(current)) {
                hasLower = true;
            } else if (Character.isDigit(current)) {
                hasDigit = true;
            } else {
                hasSymbol = true;
            }
        }
        return hasUpper && hasLower && hasDigit && hasSymbol;
    }
}
