package com.navalgo.backend.auth;

import com.navalgo.backend.security.JwtService;
import com.navalgo.backend.worker.Worker;
import com.navalgo.backend.worker.WorkerRepository;
import com.navalgo.backend.worker.WorkerService;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.http.ResponseCookie;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.security.crypto.password.PasswordEncoder;

import java.util.Map;

@Service
@Transactional(readOnly = true)
public class AuthService {

    private final WorkerRepository workerRepository;
    private final PasswordEncoder passwordEncoder;
    private final JwtService jwtService;
    private final WorkerService workerService;
    private final RefreshTokenService refreshTokenService;
    private final AuthCookieService authCookieService;
    private final LoginAttemptService loginAttemptService;

    public AuthService(WorkerRepository workerRepository,
                       PasswordEncoder passwordEncoder,
                       JwtService jwtService,
                       WorkerService workerService,
                       RefreshTokenService refreshTokenService,
                       AuthCookieService authCookieService,
                       LoginAttemptService loginAttemptService) {
        this.workerRepository = workerRepository;
        this.passwordEncoder = passwordEncoder;
        this.jwtService = jwtService;
        this.workerService = workerService;
        this.refreshTokenService = refreshTokenService;
        this.authCookieService = authCookieService;
        this.loginAttemptService = loginAttemptService;
    }

    @Transactional
    public AuthenticatedSession login(LoginRequest request, String clientIp, String userAgent) {
        loginAttemptService.checkAllowed(request.email(), clientIp);

        Worker worker = workerRepository.findByEmailIgnoreCase(request.email())
                .orElseThrow(InvalidCredentialsException::new);

        if (!worker.isActive() || !passwordEncoder.matches(request.password(), worker.getPasswordHash())) {
            loginAttemptService.recordFailure(request.email(), clientIp);
            throw new InvalidCredentialsException();
        }

        loginAttemptService.recordSuccess(request.email(), clientIp);

        refreshTokenService.revokeAllForWorker(worker.getId());

        String accessToken = jwtService.generateToken(worker.getEmail(), Map.of(
                "role", worker.getRole().name(),
                "userId", worker.getId()
        ));
        RefreshTokenService.IssuedRefreshToken refreshToken = refreshTokenService.issue(worker, clientIp, userAgent);

        return new AuthenticatedSession(
                buildResponse(worker, accessToken),
                refreshToken.token()
        );
    }

    @Transactional
    public AuthenticatedSession refresh(HttpServletRequest request, String clientIp, String userAgent) {
        String rawRefreshToken = authCookieService.extractRefreshToken(request)
                .orElseThrow(InvalidCredentialsException::new);
        RefreshTokenService.RefreshSession session = refreshTokenService.rotate(rawRefreshToken, clientIp, userAgent);
        String accessToken = jwtService.generateToken(session.worker().getEmail(), Map.of(
                "role", session.worker().getRole().name(),
                "userId", session.worker().getId()
        ));

        return new AuthenticatedSession(buildResponse(session.worker(), accessToken), session.refreshToken());
    }

    @Transactional
    public void logout(HttpServletRequest request, String authenticatedEmail) {
        authCookieService.extractRefreshToken(request).ifPresent(refreshTokenService::revoke);
        if (authenticatedEmail != null && !authenticatedEmail.isBlank()) {
            workerRepository.findByEmailIgnoreCase(authenticatedEmail)
                    .ifPresent(worker -> refreshTokenService.revokeAllForWorker(worker.getId()));
        }
    }

    @Transactional
    public void changePassword(String email, ChangePasswordRequest request) {
        workerService.changeOwnPassword(email, request.currentPassword(), request.newPassword());
    }

    public ResponseCookie buildRefreshCookie(String refreshToken) {
        return authCookieService.createRefreshTokenCookie(refreshToken);
    }

    public ResponseCookie clearRefreshCookie() {
        return authCookieService.clearRefreshTokenCookie();
    }

    private LoginResponse buildResponse(Worker worker, String accessToken) {
        AuthUserDto userDto = new AuthUserDto(
                worker.getId(),
                worker.getFullName(),
                worker.getEmail(),
                worker.getRole(),
                worker.isMustChangePassword(),
            worker.isCanEditWorkOrders(),
            worker.getPhotoUrl()
        );

        return new LoginResponse(userDto, accessToken, "Bearer", jwtService.calculateExpiryInstant());
    }

    public record AuthenticatedSession(LoginResponse response, String refreshToken) {
    }
}
