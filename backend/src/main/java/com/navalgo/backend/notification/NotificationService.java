package com.navalgo.backend.notification;

import com.navalgo.backend.common.Role;
import com.navalgo.backend.worker.Worker;
import com.navalgo.backend.worker.WorkerRepository;
import jakarta.persistence.EntityNotFoundException;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.Collection;
import java.util.List;

@Service
@Transactional(readOnly = true)
public class NotificationService {

    private static final Logger log = LoggerFactory.getLogger(NotificationService.class);

    private final NotificationRepository notificationRepository;
    private final PushNotificationService pushNotificationService;
    private final WorkerRepository workerRepository;
    private final ResendEmailService resendEmailService;

    public NotificationService(NotificationRepository notificationRepository,
                               PushNotificationService pushNotificationService,
                               WorkerRepository workerRepository,
                               ResendEmailService resendEmailService) {
        this.notificationRepository = notificationRepository;
        this.pushNotificationService = pushNotificationService;
        this.workerRepository = workerRepository;
        this.resendEmailService = resendEmailService;
    }

    public List<NotificationDto> listForUser(String email) {
        Worker worker = requireWorker(email);
        return notificationRepository.findByWorkerIdOrderByCreatedAtDesc(worker.getId())
                .stream()
                .map(NotificationDto::from)
                .toList();
    }

    public UnreadCountDto unreadCountForUser(String email) {
        Worker worker = requireWorker(email);
        long count = notificationRepository.countByWorkerIdAndIsReadFalse(worker.getId());
        return new UnreadCountDto(count);
    }

    @Transactional
    public void markAsRead(Long notificationId, String email) {
        Worker worker = requireWorker(email);
        NotificationEntity notification = notificationRepository.findById(notificationId)
                .orElseThrow(() -> new EntityNotFoundException("Notificacion no encontrada"));

        if (!notification.getWorker().getId().equals(worker.getId())) {
            throw new IllegalArgumentException("No puedes modificar esta notificacion");
        }

        notification.setRead(true);
        notificationRepository.save(notification);
    }

    @Transactional
    public void markAllAsRead(String email) {
        Worker worker = requireWorker(email);
        List<NotificationEntity> notifications = notificationRepository.findByWorkerIdOrderByCreatedAtDesc(worker.getId());
        for (NotificationEntity notification : notifications) {
            if (!notification.isRead()) {
                notification.setRead(true);
            }
        }
        notificationRepository.saveAll(notifications);
    }

    @Transactional
    public void notifyAdmins(String title, String message, String actionRoute, NotificationType type) {
        notifyAdmins(title, message, actionRoute, type, NotificationDeliveryOptions.DEFAULT);
    }

    @Transactional
    public void notifyAdmins(String title,
                             String message,
                             String actionRoute,
                             NotificationType type,
                             NotificationDeliveryOptions options) {
        List<Worker> admins = workerRepository.findByRoleAndActiveTrue(Role.ADMIN);
        deliver(admins, title, message, actionRoute, type, options);
    }

    @Transactional
    public void notifyWorker(Long workerId, String title, String message, String actionRoute, NotificationType type) {
        notifyWorker(workerId, title, message, actionRoute, type, NotificationDeliveryOptions.DEFAULT);
    }

    @Transactional
    public void notifyWorker(Long workerId,
                             String title,
                             String message,
                             String actionRoute,
                             NotificationType type,
                             NotificationDeliveryOptions options) {
        Worker worker = workerRepository.findById(workerId)
                .orElseThrow(() -> new EntityNotFoundException("Trabajador no encontrado"));
        deliver(List.of(worker), title, message, actionRoute, type, options);
    }

    @Transactional
    public void notifyWorkers(Collection<Long> workerIds,
                              String title,
                              String message,
                              String actionRoute,
                              NotificationType type) {
        notifyWorkers(workerIds, title, message, actionRoute, type, NotificationDeliveryOptions.DEFAULT);
    }

    @Transactional
    public void notifyWorkers(Collection<Long> workerIds,
                              String title,
                              String message,
                              String actionRoute,
                              NotificationType type,
                              NotificationDeliveryOptions options) {
        if (workerIds == null || workerIds.isEmpty()) {
            return;
        }

        List<Worker> workers = workerRepository.findAllById(workerIds).stream()
                .filter(Worker::isActive)
                .toList();
        deliver(workers, title, message, actionRoute, type, options);
    }

    private void deliver(List<Worker> workers,
                         String title,
                         String message,
                         String actionRoute,
                         NotificationType type,
                         NotificationDeliveryOptions options) {
        for (Worker worker : workers) {
            NotificationEntity saved = notificationRepository.save(
                    buildNotification(worker, title, message, actionRoute, type)
            );
            PushNotificationService.PushDeliveryResult pushResult = pushNotificationService.sendToWorker(
                    worker.getId(),
                    title,
                    message,
                    actionRoute,
                    type,
                    saved.getId()
            );
            if (options.emailFallbackWhenPushUnavailable() && pushResult.shouldFallbackToEmail()) {
                sendNotificationFallbackEmail(worker, title, message, pushResult);
            }
        }
    }

    private void sendNotificationFallbackEmail(Worker worker,
                                               String title,
                                               String message,
                                               PushNotificationService.PushDeliveryResult pushResult) {
        try {
            resendEmailService.sendNotificationFallback(
                    worker.getFullName(),
                    worker.getEmail(),
                    title,
                    message
            );
        } catch (RuntimeException exception) {
            log.warn(
                    "No se pudo enviar el email fallback de notificacion. workerId={}, title={}, pushReason={}",
                    worker.getId(),
                    title,
                    pushResult.failureReason(),
                    exception
            );
        }
    }

    private NotificationEntity buildNotification(Worker worker,
                                                 String title,
                                                 String message,
                                                 String actionRoute,
                                                 NotificationType type) {
        NotificationEntity entity = new NotificationEntity();
        entity.setWorker(worker);
        entity.setTitle(title);
        entity.setMessage(message);
        entity.setActionRoute(actionRoute);
        entity.setType(type);
        entity.setRead(false);
        entity.setCreatedAt(Instant.now());
        return entity;
    }

    private Worker requireWorker(String email) {
        return workerRepository.findByEmailIgnoreCase(email)
                .orElseThrow(() -> new EntityNotFoundException("Usuario no encontrado"));
    }
}
