package com.navalgo.backend.notification;

import com.navalgo.backend.worker.Worker;
import com.navalgo.backend.worker.WorkerRepository;
import jakarta.persistence.EntityNotFoundException;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;
import java.util.TreeMap;

@Service
@Transactional(readOnly = true)
public class PushNotificationService {

    private static final Logger log = LoggerFactory.getLogger(PushNotificationService.class);

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
        log.info(
                "Push token registrado. workerId={}, platform={}, token={}",
                worker.getId(),
                entity.getPlatform(),
                maskToken(normalizedToken)
        );
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
                    log.info(
                            "Push token desactivado. workerId={}, platform={}, token={}",
                            worker.getId(),
                            token.getPlatform(),
                            maskToken(token.getToken())
                    );
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
            log.info("No hay push tokens activos para workerId={}", workerId);
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
        log.warn("Firebase marco {} token(s) invalidos para workerId={}", invalidEntities.size(), workerId);
    }

    public PushDebugStatusDto getDebugStatus() {
        FirebasePushGateway.FirebasePushDebugDto firebase = firebasePushGateway.debugStatus();
        List<WorkerPushToken> activeTokens = workerPushTokenRepository.findByActiveTrueOrderByLastSeenAtDesc();
        Map<String, Integer> countsByPlatform = new TreeMap<>();
        for (WorkerPushToken token : activeTokens) {
            countsByPlatform.merge(normalizePlatform(token.getPlatform()), 1, Integer::sum);
        }

        List<PushDebugPlatformCountDto> platformCounts = countsByPlatform.entrySet().stream()
                .map(entry -> new PushDebugPlatformCountDto(entry.getKey(), entry.getValue()))
                .toList();

        return new PushDebugStatusDto(
                firebase.enabled(),
                firebase.credentialSource(),
                firebase.credentialsReadable(),
                firebase.initializationAttempted(),
                firebase.initialized(),
                firebase.lastInitializationAttemptAt(),
                firebase.lastInitializationSuccessAt(),
                firebase.lastInitializationError(),
                firebase.lastSendAttemptAt(),
                firebase.lastSendSuccessAt(),
                firebase.lastSendError(),
                firebase.lastRequestedTokenCount(),
                firebase.lastInvalidTokenCount(),
                activeTokens.size(),
                platformCounts
        );
    }

    public List<PushDebugTokenDto> listDebugTokens() {
        List<WorkerPushToken> tokens = workerPushTokenRepository.findByActiveTrueOrderByLastSeenAtDesc();
        List<PushDebugTokenDto> result = new ArrayList<>();
        for (WorkerPushToken token : tokens) {
            Worker worker = token.getWorker();
            result.add(new PushDebugTokenDto(
                    worker.getId(),
                    worker.getFullName(),
                    worker.getEmail(),
                    normalizePlatform(token.getPlatform()),
                    token.isActive(),
                    maskToken(token.getToken()),
                    token.getCreatedAt(),
                    token.getLastSeenAt()
            ));
        }
        result.sort(Comparator.comparing(PushDebugTokenDto::lastSeenAt, Comparator.nullsLast(Comparator.reverseOrder())));
        return result;
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

    private String maskToken(String token) {
        if (token == null || token.isBlank()) {
            return "";
        }
        if (token.length() <= 12) {
            return token;
        }
        return token.substring(0, 6) + "..." + token.substring(token.length() - 6);
    }
}
