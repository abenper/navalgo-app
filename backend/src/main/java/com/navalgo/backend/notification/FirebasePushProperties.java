package com.navalgo.backend.notification;

import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.stereotype.Component;

@Component
@ConfigurationProperties(prefix = "app.firebase")
public class FirebasePushProperties {

    private boolean enabled = true;
    private String serviceAccountPath;
    private String serviceAccountJson;

    public boolean isEnabled() {
        return enabled;
    }

    public void setEnabled(boolean enabled) {
        this.enabled = enabled;
    }

    public String getServiceAccountPath() {
        return serviceAccountPath;
    }

    public void setServiceAccountPath(String serviceAccountPath) {
        this.serviceAccountPath = serviceAccountPath;
    }

    public String getServiceAccountJson() {
        return serviceAccountJson;
    }

    public void setServiceAccountJson(String serviceAccountJson) {
        this.serviceAccountJson = serviceAccountJson;
    }

    public boolean isConfigured() {
        return enabled && hasText(serviceAccountPath) || enabled && hasText(serviceAccountJson);
    }

    private boolean hasText(String value) {
        return value != null && !value.isBlank();
    }
}