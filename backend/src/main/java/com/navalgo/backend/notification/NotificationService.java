package com.navalgo.backend.notification;

import com.navalgo.backend.common.Role;
import com.navalgo.backend.worker.Worker;
import com.navalgo.backend.worker.WorkerRepository;
import jakarta.persistence.EntityNotFoundException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.List;

@Service
@Transactional(readOnly = true)
public class NotificationService {

    private final NotificationRepository notificationRepository;
    private final WorkerRepository workerRepository;

    public NotificationService(NotificationRepository notificationRepository,
                               WorkerRepository workerRepository) {
        this.notificationRepository = notificationRepository;
        this.workerRepository = workerRepository;
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
        List<Worker> admins = workerRepository.findByRoleAndActiveTrue(Role.ADMIN);
        for (Worker admin : admins) {
            notificationRepository.save(buildNotification(admin, title, message, actionRoute, type));
        }
    }

    @Transactional
    public void notifyWorker(Long workerId, String title, String message, String actionRoute, NotificationType type) {
        Worker worker = workerRepository.findById(workerId)
                .orElseThrow(() -> new EntityNotFoundException("Trabajador no encontrado"));
        notificationRepository.save(buildNotification(worker, title, message, actionRoute, type));
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
