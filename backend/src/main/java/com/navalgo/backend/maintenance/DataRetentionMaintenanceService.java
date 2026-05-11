package com.navalgo.backend.maintenance;

import com.navalgo.backend.auth.EmailVerificationTokenRepository;
import com.navalgo.backend.auth.PasswordResetTokenRepository;
import com.navalgo.backend.auth.RefreshTokenRepository;
import com.navalgo.backend.auth.RegistrationInvitationRepository;
import com.navalgo.backend.notification.NotificationRepository;
import com.navalgo.backend.notification.WorkerPushTokenRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.time.temporal.ChronoUnit;

@Service
public class DataRetentionMaintenanceService {

    private static final Logger log = LoggerFactory.getLogger(DataRetentionMaintenanceService.class);

    private final NotificationRepository notificationRepository;
    private final RefreshTokenRepository refreshTokenRepository;
    private final WorkerPushTokenRepository workerPushTokenRepository;
    private final RegistrationInvitationRepository registrationInvitationRepository;
    private final PasswordResetTokenRepository passwordResetTokenRepository;
    private final EmailVerificationTokenRepository emailVerificationTokenRepository;
    private final long readNotificationsRetentionDays;
    private final long refreshTokenRetentionDays;
    private final long inactivePushTokenRetentionDays;
    private final long authArtifactRetentionDays;

    public DataRetentionMaintenanceService(
            NotificationRepository notificationRepository,
            RefreshTokenRepository refreshTokenRepository,
            WorkerPushTokenRepository workerPushTokenRepository,
            RegistrationInvitationRepository registrationInvitationRepository,
            PasswordResetTokenRepository passwordResetTokenRepository,
            EmailVerificationTokenRepository emailVerificationTokenRepository,
            @Value("${app.retention.read-notifications-days:90}") long readNotificationsRetentionDays,
            @Value("${app.retention.refresh-tokens-days:30}") long refreshTokenRetentionDays,
            @Value("${app.retention.inactive-push-tokens-days:90}") long inactivePushTokenRetentionDays,
            @Value("${app.retention.auth-artifacts-days:30}") long authArtifactRetentionDays
    ) {
        this.notificationRepository = notificationRepository;
        this.refreshTokenRepository = refreshTokenRepository;
        this.workerPushTokenRepository = workerPushTokenRepository;
        this.registrationInvitationRepository = registrationInvitationRepository;
        this.passwordResetTokenRepository = passwordResetTokenRepository;
        this.emailVerificationTokenRepository = emailVerificationTokenRepository;
        this.readNotificationsRetentionDays = readNotificationsRetentionDays;
        this.refreshTokenRetentionDays = refreshTokenRetentionDays;
        this.inactivePushTokenRetentionDays = inactivePushTokenRetentionDays;
        this.authArtifactRetentionDays = authArtifactRetentionDays;
    }

    @Transactional
    @Scheduled(cron = "${app.scheduling.data-retention-cron:0 30 3 1 * *}")
    public void purgeLowValueData() {
        Instant now = Instant.now();

        long deletedReadNotifications = notificationRepository.deleteByIsReadTrueAndCreatedAtBefore(
                now.minus(readNotificationsRetentionDays, ChronoUnit.DAYS)
        );
        long deletedExpiredRefreshTokens = refreshTokenRepository.deleteByExpiresAtBefore(
                now.minus(refreshTokenRetentionDays, ChronoUnit.DAYS)
        );
        long deletedRevokedRefreshTokens = refreshTokenRepository.deleteByRevokedAtBefore(
                now.minus(refreshTokenRetentionDays, ChronoUnit.DAYS)
        );
        long deletedInactivePushTokens = workerPushTokenRepository.deleteByActiveFalseAndLastSeenAtBefore(
                now.minus(inactivePushTokenRetentionDays, ChronoUnit.DAYS)
        );
        long deletedExpiredInvitations = registrationInvitationRepository.deleteByExpiresAtBefore(
                now.minus(authArtifactRetentionDays, ChronoUnit.DAYS)
        );
        long deletedConsumedInvitations = registrationInvitationRepository.deleteByConsumedAtBefore(
                now.minus(authArtifactRetentionDays, ChronoUnit.DAYS)
        );
        long deletedExpiredPasswordResetTokens = passwordResetTokenRepository.deleteByExpiresAtBefore(
                now.minus(authArtifactRetentionDays, ChronoUnit.DAYS)
        );
        long deletedConsumedPasswordResetTokens = passwordResetTokenRepository.deleteByConsumedAtBefore(
                now.minus(authArtifactRetentionDays, ChronoUnit.DAYS)
        );
        long deletedExpiredEmailVerificationTokens = emailVerificationTokenRepository.deleteByExpiresAtBefore(
                now.minus(authArtifactRetentionDays, ChronoUnit.DAYS)
        );
        long deletedConsumedEmailVerificationTokens = emailVerificationTokenRepository.deleteByConsumedAtBefore(
                now.minus(authArtifactRetentionDays, ChronoUnit.DAYS)
        );

        log.info(
                "Purga de datos no criticos completada. notifications={}, refreshExpired={}, refreshRevoked={}, pushTokens={}, invitations={}, passwordResets={}, emailVerifications={}",
                deletedReadNotifications,
                deletedExpiredRefreshTokens,
                deletedRevokedRefreshTokens,
                deletedInactivePushTokens,
                deletedExpiredInvitations + deletedConsumedInvitations,
                deletedExpiredPasswordResetTokens + deletedConsumedPasswordResetTokens,
                deletedExpiredEmailVerificationTokens + deletedConsumedEmailVerificationTokens
        );
    }
}
