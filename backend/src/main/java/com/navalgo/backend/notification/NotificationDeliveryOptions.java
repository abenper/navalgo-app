package com.navalgo.backend.notification;

public record NotificationDeliveryOptions(boolean emailFallbackWhenPushUnavailable) {

    public static final NotificationDeliveryOptions DEFAULT = new NotificationDeliveryOptions(false);
    public static final NotificationDeliveryOptions EMAIL_FALLBACK = new NotificationDeliveryOptions(true);
}
