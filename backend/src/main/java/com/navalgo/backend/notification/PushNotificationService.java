package com.navalgo.backend.notification;

import com.navalgo.backend.worker.Worker;
import com.navalgo.backend.worker.WorkerRepository;
import jakarta.persistence.EntityNotFoundException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.List;
import java.util.Locale;
import java.util.Set;

@Service
@Transactional(readOnly = true)
public class PushNotificationService {

    private final FirebasePushGateway firebasePushGateway;
    private final WorkerPushTokenRepository workerPushTokenRepository;
    private final WorkerRepository workerRepository;

    public PushNotificationService(FirebasePushGateway firebasePushGateway,
                                   WorkerPushTokenRepository workerPushTokenRepository,
                                   WorkerRepository workerRepository) {
        this.firebasePushGateway = firebasePushGateway;
        this.workerPushTokenRepository = workerPushTokenRepository;
        this.workerRepository = workerRepository;
    }

    @Transactional
    public void registerToken(String email, PushTokenRegistrationRequest request) {
        Worker worker = requireWorker(email);
        String normalizedToken = request.token().trim();
        Instant now = Instant.now();

        WorkerPushToken entity = workerPushTokenRepository.findByToken(normalizedToken)
                .orElseGet(WorkerPushToken::new);

        if (entity.getCreatedAt() == null) {
            entity.setCreatedAt(now);
        }

        entity.setWorker(worker);
        entity.setToken(normalizedToken);
        entity.setPlatform(normalizePlatform(request.platform()));
        entity.setActive(true);
        entity.setLastSeenAt(now);
        workerPushTokenRepository.save(entity);
    }

    @Transactional
    public void unregisterToken(String email, PushTokenUnregistrationRequest request) {
        Worker worker = requireWorker(email);
        workerPushTokenRepository.findByToken(request.token().trim())
                .filter(token -> token.getWorker().getId().equals(worker.getId()))
                .ifPresent(token -> {
                    token.setActive(false);
                    token.setLastSeenAt(Instant.now());
                    workerPushTokenRepository.save(token);
                });
    }

    @Transactional
    public void sendToWorker(Long workerId,
                             String title,
                             String message,
                             String actionRoute,
                             NotificationType type,
                             Long notificationId) {
        List<WorkerPushToken> activeTokens = workerPushTokenRepository.findByWorkerIdAndActiveTrue(workerId);
        if (activeTokens.isEmpty()) {
            return;
        }

        List<String> tokens = activeTokens.stream()
                .map(WorkerPushToken::getToken)
                .distinct()
                .toList();

        Set<String> invalidTokens = firebasePushGateway.send(tokens, title, message, actionRoute, type, notificationId);
        if (invalidTokens.isEmpty()) {
            return;
        }

        Instant now = Instant.now();
        List<WorkerPushToken> invalidEntities = workerPushTokenRepository.findByTokenIn(invalidTokens);
        for (WorkerPushToken invalidEntity : invalidEntities) {
            invalidEntity.setActive(false);
            invalidEntity.setLastSeenAt(now);
        }
        workerPushTokenRepository.saveAll(invalidEntities);
    }

    private Worker requireWorker(String email) {
        return workerRepository.findByEmailIgnoreCase(email)
                .orElseThrow(() -> new EntityNotFoundException("Usuario no encontrado"));
    }

    private String normalizePlatform(String platform) {
        if (platform == null || platform.isBlank()) {
            return "UNKNOWN";
        }
        return platform.trim().toUpperCase(Locale.ROOT);
    }
}