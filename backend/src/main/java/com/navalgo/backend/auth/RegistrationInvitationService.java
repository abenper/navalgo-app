package com.navalgo.backend.auth;

import com.navalgo.backend.notification.ResendEmailService;
import com.navalgo.backend.worker.Worker;
import com.navalgo.backend.worker.WorkerRepository;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.util.UriComponentsBuilder;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.security.SecureRandom;
import java.time.Instant;
import java.util.Base64;

@Service
@Transactional(readOnly = true)
public class RegistrationInvitationService {

    private static final String SCREEN_QUERY_PARAM = "screen";
    private static final String INVITATION_SCREEN = "complete-registration";
    private static final String PRIVACY_SCREEN = "privacy";

    private final RegistrationInvitationRepository invitationRepository;
    private final WorkerRepository workerRepository;
    private final PasswordEncoder passwordEncoder;
    private final RefreshTokenService refreshTokenService;
    private final ResendEmailService resendEmailService;
    private final String frontendBaseUrl;
    private final long invitationTtlHours;
    private final SecureRandom secureRandom = new SecureRandom();

    public RegistrationInvitationService(
            RegistrationInvitationRepository invitationRepository,
            WorkerRepository workerRepository,
            PasswordEncoder passwordEncoder,
            RefreshTokenService refreshTokenService,
            ResendEmailService resendEmailService,
            @Value("${app.frontend.base-url:https://naval-go.com}") String frontendBaseUrl,
            @Value("${app.auth.registration-invitation-ttl-hours:72}") long invitationTtlHours
    ) {
        this.invitationRepository = invitationRepository;
        this.workerRepository = workerRepository;
        this.passwordEncoder = passwordEncoder;
        this.refreshTokenService = refreshTokenService;
        this.resendEmailService = resendEmailService;
        this.frontendBaseUrl = frontendBaseUrl;
        this.invitationTtlHours = invitationTtlHours;
    }

    @Transactional
    public boolean issueInvitation(Worker worker) {
        invitationRepository.deleteByWorker_Id(worker.getId());

        String rawToken = generateToken();
        RegistrationInvitation invitation = new RegistrationInvitation();
        invitation.setWorker(worker);
        invitation.setTokenHash(hashToken(rawToken));
        invitation.setCreatedAt(Instant.now());
        invitation.setExpiresAt(Instant.now().plusSeconds(invitationTtlHours * 3600));
        invitationRepository.save(invitation);

        return resendEmailService.sendRegistrationInvitation(
                worker.getFullName(),
                worker.getEmail(),
                buildPublicUrl(INVITATION_SCREEN, rawToken),
                buildPublicUrl(PRIVACY_SCREEN, null)
        );
    }

    public RegistrationInvitationStatusResponse getInvitationStatus(String rawToken) {
        RegistrationInvitation invitation = requireValidInvitation(rawToken);
        Worker worker = invitation.getWorker();
        return new RegistrationInvitationStatusResponse(
                worker.getFullName(),
                worker.getEmail(),
                invitation.getExpiresAt()
        );
    }

    @Transactional
    public void completeRegistration(CompleteRegistrationRequest request) {
        String password = request.password() == null ? "" : request.password().trim();
        if (!isStrongPassword(password)) {
            throw new IllegalArgumentException("La contrasena debe tener minimo 12 caracteres e incluir mayuscula, minuscula, numero y simbolo");
        }

        RegistrationInvitation invitation = requireValidInvitation(request.token());
        Worker worker = invitation.getWorker();
        worker.setPasswordHash(passwordEncoder.encode(password));
        worker.setMustChangePassword(false);
        workerRepository.save(worker);

        invitation.setConsumedAt(Instant.now());
        invitationRepository.save(invitation);
        invitationRepository.deleteByWorker_Id(worker.getId());
        refreshTokenService.revokeAllForWorker(worker.getId());
    }

    private RegistrationInvitation requireValidInvitation(String rawToken) {
        if (rawToken == null || rawToken.isBlank()) {
            throw new IllegalArgumentException("El enlace de activacion no es valido o ha caducado");
        }

        RegistrationInvitation invitation = invitationRepository.findByTokenHash(hashToken(rawToken))
                .orElseThrow(() -> new IllegalArgumentException("El enlace de activacion no es valido o ha caducado"));

        if (invitation.getConsumedAt() != null || invitation.getExpiresAt().isBefore(Instant.now())) {
            throw new IllegalArgumentException("El enlace de activacion no es valido o ha caducado");
        }
        return invitation;
    }

    private String buildPublicUrl(String screen, String token) {
        UriComponentsBuilder builder = UriComponentsBuilder.fromUriString(frontendBaseUrl)
                .replaceQuery(null)
                .queryParam(SCREEN_QUERY_PARAM, screen);
        if (token != null && !token.isBlank()) {
            builder.queryParam("token", token);
        }
        return builder.build(true).toUriString();
    }

    private String generateToken() {
        byte[] bytes = new byte[32];
        secureRandom.nextBytes(bytes);
        return Base64.getUrlEncoder().withoutPadding().encodeToString(bytes);
    }

    private String hashToken(String rawToken) {
        try {
            byte[] digest = MessageDigest.getInstance("SHA-256")
                    .digest(rawToken.getBytes(StandardCharsets.UTF_8));
            StringBuilder builder = new StringBuilder(digest.length * 2);
            for (byte current : digest) {
                builder.append(String.format("%02x", current));
            }
            return builder.toString();
        } catch (NoSuchAlgorithmException exception) {
            throw new IllegalStateException("No se pudo calcular el hash del token", exception);
        }
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
