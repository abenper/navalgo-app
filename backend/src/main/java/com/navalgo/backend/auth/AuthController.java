package com.navalgo.backend.auth;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.validation.Valid;
import org.springframework.http.HttpHeaders;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/auth")
public class AuthController {

    private final AuthService authService;

    public AuthController(AuthService authService) {
        this.authService = authService;
    }

    @PostMapping("/login")
    public ResponseEntity<LoginResponse> login(@RequestBody @Valid LoginRequest request,
                                               HttpServletRequest httpRequest,
                                               HttpServletResponse response) {
        AuthService.AuthenticatedSession session = authService.login(
                request,
                extractClientIp(httpRequest),
                httpRequest.getHeader(HttpHeaders.USER_AGENT)
        );
        response.addHeader(HttpHeaders.SET_COOKIE, authService.buildRefreshCookie(session.refreshToken()).toString());
        return ResponseEntity.ok(session.response());
    }

    @PostMapping("/refresh")
    public ResponseEntity<LoginResponse> refresh(HttpServletRequest request, HttpServletResponse response) {
        AuthService.AuthenticatedSession session = authService.refresh(
                request,
                extractClientIp(request),
                request.getHeader(HttpHeaders.USER_AGENT)
        );
        response.addHeader(HttpHeaders.SET_COOKIE, authService.buildRefreshCookie(session.refreshToken()).toString());
        return ResponseEntity.ok(session.response());
    }

    @PostMapping("/logout")
    public ResponseEntity<Void> logout(HttpServletRequest request, HttpServletResponse response) {
        authService.logout(request);
        response.addHeader(HttpHeaders.SET_COOKIE, authService.clearRefreshCookie().toString());
        return ResponseEntity.noContent().build();
    }

    @PostMapping("/change-password")
    @PreAuthorize("hasAnyRole('ADMIN','WORKER')")
    public ResponseEntity<Void> changePassword(@RequestBody @Valid ChangePasswordRequest request,
                                               Authentication authentication) {
        authService.changePassword(authentication.getName(), request);
        return ResponseEntity.noContent().build();
    }

    private String extractClientIp(HttpServletRequest request) {
        String forwarded = request.getHeader("X-Forwarded-For");
        if (forwarded != null && !forwarded.isBlank()) {
            return forwarded.split(",")[0].trim();
        }
        return request.getRemoteAddr();
    }
}
