package com.navalgo.backend.notification;

import java.time.Instant;

public record NotificationDto(
        Long id,
        String title,
        String message,
        NotificationType type,
        String actionRoute,
        boolean isRead,
        Instant createdAt
) {
    public static NotificationDto from(NotificationEntity entity) {
        return new NotificationDto(
                entity.getId(),
                entity.getTitle(),
                entity.getMessage(),
                entity.getType(),
                entity.getActionRoute(),
                entity.isRead(),
                entity.getCreatedAt()
        );
    }
}
