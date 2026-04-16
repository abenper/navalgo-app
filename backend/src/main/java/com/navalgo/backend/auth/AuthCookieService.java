package com.navalgo.backend.auth;

import jakarta.servlet.http.Cookie;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.ResponseCookie;
import org.springframework.stereotype.Service;

import java.time.Duration;
import java.util.Arrays;
import java.util.Optional;

@Service
public class AuthCookieService {

    private final String refreshCookieName;
    private final String sameSite;
    private final boolean secure;
    private final String cookiePath;
    private final Duration refreshTokenDuration;

    public AuthCookieService(
            @Value("${app.security.cookies.refresh-name:navalgo_refresh_token}") String refreshCookieName,
            @Value("${app.security.cookies.same-site:Lax}") String sameSite,
            @Value("${app.security.cookies.secure:false}") boolean secure,
            @Value("${app.security.cookies.path:/api/auth}") String cookiePath,
            @Value("${app.jwt.refresh-expiration-ms:604800000}") long refreshExpirationMs
    ) {
        this.refreshCookieName = refreshCookieName;
        this.sameSite = sameSite;
        this.secure = secure;
        this.cookiePath = cookiePath;
        this.refreshTokenDuration = Duration.ofMillis(refreshExpirationMs);
    }

    public ResponseCookie createRefreshTokenCookie(String refreshToken) {
        return ResponseCookie.from(refreshCookieName, refreshToken)
                .httpOnly(true)
                .secure(secure)
                .sameSite(sameSite)
                .path(cookiePath)
                .maxAge(refreshTokenDuration)
                .build();
    }

    public ResponseCookie clearRefreshTokenCookie() {
        return ResponseCookie.from(refreshCookieName, "")
                .httpOnly(true)
                .secure(secure)
                .sameSite(sameSite)
                .path(cookiePath)
                .maxAge(Duration.ZERO)
                .build();
    }

    public Optional<String> extractRefreshToken(HttpServletRequest request) {
        Cookie[] cookies = request.getCookies();
        if (cookies == null || cookies.length == 0) {
            return Optional.empty();
        }

        return Arrays.stream(cookies)
                .filter(cookie -> refreshCookieName.equals(cookie.getName()))
                .map(Cookie::getValue)
                .filter(value -> value != null && !value.isBlank())
                .findFirst();
    }
}