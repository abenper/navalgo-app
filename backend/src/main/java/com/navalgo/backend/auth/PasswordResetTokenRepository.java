package com.navalgo.backend.auth;

import org.springframework.data.jpa.repository.JpaRepository;

import java.time.Instant;
import java.util.Optional;

public interface PasswordResetTokenRepository extends JpaRepository<PasswordResetToken, Long> {
    Optional<PasswordResetToken> findByTokenHash(String tokenHash);
    void deleteByWorker_Id(Long workerId);
    long deleteByExpiresAtBefore(Instant expiresAt);
    long deleteByConsumedAtBefore(Instant consumedAt);
}
