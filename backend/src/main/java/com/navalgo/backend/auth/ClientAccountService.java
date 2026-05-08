package com.navalgo.backend.auth;

import com.navalgo.backend.common.InputSanitizer;
import com.navalgo.backend.common.Role;
import com.navalgo.backend.fleet.Owner;
import com.navalgo.backend.fleet.OwnerRepository;
import com.navalgo.backend.fleet.OwnerType;
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
public class ClientAccountService {

    private static final String SCREEN_QUERY_PARAM = "screen";
    private static final String VERIFY_EMAIL_SCREEN = "verify-email";
    private static final String PRIVACY_SCREEN = "privacy";

    private final WorkerRepository workerRepository;
    private final OwnerRepository ownerRepository;
    private final PasswordEncoder passwordEncoder;
    private final InputSanitizer inputSanitizer;
    private final EmailVerificationTokenRepository emailVerificationTokenRepository;
    private final SecureTokenSupport secureTokenSupport;
    private final ResendEmailService resendEmailService;
    private final LoginAttemptService loginAttemptService;
    private final String frontendBaseUrl;
    private final long emailVerificationTtlHours;

    public ClientAccountService(WorkerRepository workerRepository,
                                OwnerRepository ownerRepository,
                                PasswordEncoder passwordEncoder,
                                InputSanitizer inputSanitizer,
                                EmailVerificationTokenRepository emailVerificationTokenRepository,
                                SecureTokenSupport secureTokenSupport,
                                ResendEmailService resendEmailService,
                                LoginAttemptService loginAttemptService,
                                @Value("${app.frontend.base-url:https://naval-go.com}") String frontendBaseUrl,
                                @Value("${app.auth.email-verification-ttl-hours:48}") long emailVerificationTtlHours) {
        this.workerRepository = workerRepository;
        this.ownerRepository = ownerRepository;
        this.passwordEncoder = passwordEncoder;
        this.inputSanitizer = inputSanitizer;
        this.emailVerificationTokenRepository = emailVerificationTokenRepository;
        this.secureTokenSupport = secureTokenSupport;
        this.resendEmailService = resendEmailService;
        this.loginAttemptService = loginAttemptService;
        this.frontendBaseUrl = frontendBaseUrl;
        this.emailVerificationTtlHours = emailVerificationTtlHours;
    }

    @Transactional
    public void signup(ClientSignupRequest request, String clientIp) {
        String email = inputSanitizer.email(request.email());
        String fullName = inputSanitizer.requiredText(request.fullName(), "El nombre", 255);
        String password = request.password() == null ? "" : request.password().trim();
        String phone = inputSanitizer.optionalText(request.phone(), 255);

        loginAttemptService.checkSignupAllowed(email, clientIp);
        loginAttemptService.recordSignupAttempt(email, clientIp);

        if (!isStrongPassword(password)) {
            throw new IllegalArgumentException("La contrasena debe tener minimo 12 caracteres e incluir mayuscula, minuscula, numero y simbolo");
        }

        if (workerRepository.findByEmailIgnoreCase(email).isPresent()) {
            throw new IllegalArgumentException("Ya existe una cuenta con ese correo electronico");
        }

        Owner owner = ownerRepository.findByEmailIgnoreCase(email)
                .orElseGet(() -> createOwner(fullName, email, phone));

        workerRepository.findByOwner_Id(owner.getId()).ifPresent(existing -> {
            throw new IllegalArgumentException("Ese cliente ya tiene una cuenta asociada");
        });

        Worker worker = new Worker();
        worker.setFullName(fullName);
        worker.setEmail(email);
        worker.setPasswordHash(passwordEncoder.encode(password));
        worker.setRole(Role.CLIENT);
        worker.setActive(false);
        worker.setMustChangePassword(false);
        worker.setCanEditWorkOrders(false);
        worker.setEmailVerified(false);
        worker.setOwner(owner);
        Worker saved = workerRepository.save(worker);

        issueVerification(saved);
    }

    public EmailVerificationStatusResponse getVerificationStatus(String rawToken) {
        EmailVerificationToken token = requireVerificationToken(rawToken);
        Worker worker = token.getWorker();
        if (token.getExpiresAt().isBefore(Instant.now())) {
            throw new IllegalArgumentException("El enlace de verificacion no es valido o ha caducado");
        }
        return new EmailVerificationStatusResponse(
                worker.getFullName(),
                worker.getEmail(),
                token.getExpiresAt(),
                token.getConsumedAt() != null || worker.isEmailVerified()
        );
    }

    @Transactional
    public void verifyEmail(String rawToken) {
        EmailVerificationToken token = requireVerificationToken(rawToken);
        Worker worker = token.getWorker();
        if (token.getExpiresAt().isBefore(Instant.now())) {
            throw new IllegalArgumentException("El enlace de verificacion no es valido o ha caducado");
        }
        if (token.getConsumedAt() != null || worker.isEmailVerified()) {
            return;
        }
        worker.setEmailVerified(true);
        worker.setActive(true);
        workerRepository.save(worker);

        token.setConsumedAt(Instant.now());
        emailVerificationTokenRepository.save(token);
    }

    @Transactional
    public void issueVerification(Worker worker) {
        emailVerificationTokenRepository.deleteByWorker_Id(worker.getId());
        String rawToken = secureTokenSupport.generateUrlSafeToken(32);

        EmailVerificationToken token = new EmailVerificationToken();
        token.setWorker(worker);
        token.setTokenHash(secureTokenSupport.sha256Hex(rawToken));
        token.setCreatedAt(Instant.now());
        token.setExpiresAt(Instant.now().plusSeconds(emailVerificationTtlHours * 3600));
        emailVerificationTokenRepository.save(token);

        resendEmailService.sendEmailVerification(
                worker.getFullName(),
                worker.getEmail(),
                buildPublicUrl(VERIFY_EMAIL_SCREEN, rawToken),
                buildPublicUrl(PRIVACY_SCREEN, null)
        );
    }

    private EmailVerificationToken requireValidVerificationToken(String rawToken) {
        EmailVerificationToken token = requireVerificationToken(rawToken);
        if (token.getConsumedAt() != null || token.getExpiresAt().isBefore(Instant.now())) {
            throw new IllegalArgumentException("El enlace de verificacion no es valido o ha caducado");
        }
        return token;
    }

    private EmailVerificationToken requireVerificationToken(String rawToken) {
        if (rawToken == null || rawToken.isBlank()) {
            throw new IllegalArgumentException("El enlace de verificacion no es valido o ha caducado");
        }

        return emailVerificationTokenRepository
                .findByTokenHash(secureTokenSupport.sha256Hex(rawToken))
                .orElseThrow(() -> new IllegalArgumentException("El enlace de verificacion no es valido o ha caducado"));
    }

    private Owner createOwner(String fullName, String email, String phone) {
        Owner owner = new Owner();
        owner.setType(OwnerType.PERSON);
        owner.setDisplayName(fullName);
        owner.setDocumentId("AUTO-" + secureTokenSupport.generateUrlSafeToken(9));
        owner.setEmail(email);
        owner.setPhone(phone);
        return ownerRepository.save(owner);
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
