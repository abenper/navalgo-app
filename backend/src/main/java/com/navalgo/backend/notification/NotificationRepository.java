package com.navalgo.backend.notification;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface NotificationRepository extends JpaRepository<NotificationEntity, Long> {
    List<NotificationEntity> findByWorkerIdOrderByCreatedAtDesc(Long workerId);
    long countByWorkerIdAndIsReadFalse(Long workerId);
}
