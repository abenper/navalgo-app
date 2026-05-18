package com.navalgo.backend.notification;

import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.stereotype.Component;

@Component
@ConfigurationProperties(prefix = "app.whatsapp")
public class WhatsAppCloudProperties {

    private boolean enabled = false;
    private String verifyToken = "";
    private String apiToken = "";
    private String phoneNumberId = "";
    private String apiVersion = "v20.0";
    private String graphBaseUrl = "https://graph.facebook.com";

    public boolean isEnabled() {
        return enabled;
    }

    public void setEnabled(boolean enabled) {
        this.enabled = enabled;
    }

    public String getVerifyToken() {
        return verifyToken;
    }

    public void setVerifyToken(String verifyToken) {
        this.verifyToken = verifyToken == null ? "" : verifyToken.trim();
    }

    public String getApiToken() {
        return apiToken;
    }

    public void setApiToken(String apiToken) {
        this.apiToken = apiToken == null ? "" : apiToken.trim();
    }

    public String getPhoneNumberId() {
        return phoneNumberId;
    }

    public void setPhoneNumberId(String phoneNumberId) {
        this.phoneNumberId = phoneNumberId == null ? "" : phoneNumberId.trim();
    }

    public String getApiVersion() {
        return apiVersion;
    }

    public void setApiVersion(String apiVersion) {
        this.apiVersion = hasText(apiVersion) ? apiVersion.trim() : "v20.0";
    }

    public String getGraphBaseUrl() {
        return graphBaseUrl;
    }

    public void setGraphBaseUrl(String graphBaseUrl) {
        this.graphBaseUrl = hasText(graphBaseUrl)
                ? graphBaseUrl.trim()
                : "https://graph.facebook.com";
    }

    public boolean isConfigured() {
        return enabled
                && hasText(apiToken)
                && hasText(phoneNumberId)
                && hasText(verifyToken);
    }

    private boolean hasText(String value) {
        return value != null && !value.isBlank();
    }
}
