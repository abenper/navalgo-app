package com.navalgo.backend.auth;

import com.navalgo.backend.worker.Worker;
import com.navalgo.backend.worker.WorkerRepository;
import jakarta.persistence.EntityNotFoundException;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.security.SecureRandom;
import java.time.Instant;
import java.util.Base64;
import java.util.List;

@Service
@Transactional(readOnly = true)
public class RefreshTokenService {

    private final RefreshTokenRepository refreshTokenRepository;
    private final WorkerRepository workerRepository;
    private final SecureRandom secureRandom = new SecureRandom();
    private final long refreshExpirationMs;

    public RefreshTokenService(RefreshTokenRepository refreshTokenRepository,
                               WorkerRepository workerRepository,
                               @Value("${app.jwt.refresh-expiration-ms:604800000}") long refreshExpirationMs) {
        this.refreshTokenRepository = refreshTokenRepository;
        this.workerRepository = workerRepository;
        this.refreshExpirationMs = refreshExpirationMs;
    }

    @Transactional
    public IssuedRefreshToken issue(Worker worker, String clientIp, String userAgent) {
        String rawToken = generateOpaqueToken();
        RefreshToken refreshToken = new RefreshToken();
        refreshToken.setWorker(worker);
        refreshToken.setTokenHash(hash(rawToken));
        refreshToken.setTokenPrefix(rawToken.substring(0, Math.min(12, rawToken.length())));
        refreshToken.setCreatedAt(Instant.now());
        refreshToken.setExpiresAt(Instant.now().plusMillis(refreshExpirationMs));
        refreshToken.setIssuedIp(trimTo(clientIp, 128));
        refreshToken.setUserAgent(trimTo(userAgent, 512));
        refreshTokenRepository.save(refreshToken);
        return new IssuedRefreshToken(rawToken, refreshToken.getExpiresAt());
    }

    @Transactional
    public RefreshSession rotate(String rawToken, String clientIp, String userAgent) {
        RefreshToken refreshToken = refreshTokenRepository.findByTokenHash(hash(rawToken))
                .orElseThrow(InvalidCredentialsException::new);

        if (refreshToken.getRevokedAt() != null || refreshToken.getExpiresAt().isBefore(Instant.now())) {
            throw new InvalidCredentialsException();
        }

        Worker worker = workerRepository.findById(refreshToken.getWorker().getId())
                .orElseThrow(() -> new EntityNotFoundException("Usuario no encontrado"));

        if (!worker.isActive()) {
            revoke(rawToken);
            throw new InvalidCredentialsException();
        }

        refreshToken.setRotatedAt(Instant.now());
        refreshToken.setRevokedAt(Instant.now());

        IssuedRefreshToken nextToken = issue(worker, clientIp, userAgent);
        return new RefreshSession(worker, nextToken.token(), nextToken.expiresAt());
    }

    @Transactional
    public void revoke(String rawToken) {
        refreshTokenRepository.findByTokenHash(hash(rawToken)).ifPresent(token -> {
            token.setRevokedAt(Instant.now());
        });
    }

    @Transactional
    public void revokeAllForWorker(Long workerId) {
        List<RefreshToken> tokens = refreshTokenRepository.findAllByWorkerIdAndRevokedAtIsNull(workerId);
        Instant now = Instant.now();
        for (RefreshToken token : tokens) {
            token.setRevokedAt(now);
        }
    }

    private String generateOpaqueToken() {
        byte[] bytes = new byte[48];
        secureRandom.nextBytes(bytes);
        return Base64.getUrlEncoder().withoutPadding().encodeToString(bytes);
    }

    private String hash(String token) {
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            byte[] hashed = digest.digest(token.getBytes(StandardCharsets.UTF_8));
            return Base64.getUrlEncoder().withoutPadding().encodeToString(hashed);
        } catch (NoSuchAlgorithmException exception) {
            throw new IllegalStateException("No se pudo inicializar el hash seguro de tokens", exception);
        }
    }

    private String trimTo(String value, int maxLength) {
        if (value == null) {
            return null;
        }
        String trimmed = value.trim();
        if (trimmed.length() <= maxLength) {
            return trimmed;
        }
        return trimmed.substring(0, maxLength);
    }

    public record IssuedRefreshToken(String token, Instant expiresAt) {
    }

    public record RefreshSession(Worker worker, String refreshToken, Instant refreshTokenExpiresAt) {
    }
}