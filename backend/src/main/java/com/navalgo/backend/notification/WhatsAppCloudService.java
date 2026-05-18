package com.navalgo.backend.notification;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Service;

import java.io.IOException;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;
import java.util.LinkedHashMap;
import java.util.Map;

@Service
public class WhatsAppCloudService {

    private static final Logger log = LoggerFactory.getLogger(WhatsAppCloudService.class);

    private final ObjectMapper objectMapper;
    private final WhatsAppCloudProperties properties;
    private final HttpClient httpClient;

    public WhatsAppCloudService(
            ObjectMapper objectMapper,
            WhatsAppCloudProperties properties
    ) {
        this.objectMapper = objectMapper;
        this.properties = properties;
        this.httpClient = HttpClient.newBuilder()
                .connectTimeout(Duration.ofSeconds(10))
                .build();
    }

    public boolean sendTextMessage(String toPhone, String message) {
        if (!properties.isEnabled()) {
            log.debug("WhatsApp Cloud desactivado. No se envia mensaje a {}", toPhone);
            return false;
        }
        if (!properties.isConfigured()) {
            log.warn("WhatsApp Cloud activado pero incompleto. Revisa APP_WHATSAPP_VERIFY_TOKEN, APP_WHATSAPP_API_TOKEN y APP_WHATSAPP_PHONE_NUMBER_ID.");
            return false;
        }
        if (!hasText(toPhone) || !hasText(message)) {
            log.warn("Mensaje de WhatsApp descartado por telefono o cuerpo vacio.");
            return false;
        }

        Map<String, Object> textNode = new LinkedHashMap<>();
        textNode.put("preview_url", false);
        textNode.put("body", message.trim());

        Map<String, Object> payload = new LinkedHashMap<>();
        payload.put("messaging_product", "whatsapp");
        payload.put("to", toPhone.trim());
        payload.put("type", "text");
        payload.put("text", textNode);

        HttpRequest request;
        try {
            request = HttpRequest.newBuilder()
                    .uri(URI.create(buildMessagesUrl()))
                    .timeout(Duration.ofSeconds(15))
                    .header(HttpHeaders.AUTHORIZATION, "Bearer " + properties.getApiToken())
                    .header(HttpHeaders.CONTENT_TYPE, MediaType.APPLICATION_JSON_VALUE)
                    .POST(HttpRequest.BodyPublishers.ofString(objectMapper.writeValueAsString(payload)))
                    .build();
        } catch (JsonProcessingException exception) {
            throw new IllegalStateException("No se pudo serializar el mensaje de WhatsApp", exception);
        }

        HttpResponse<String> response;
        try {
            response = httpClient.send(request, HttpResponse.BodyHandlers.ofString());
        } catch (InterruptedException exception) {
            Thread.currentThread().interrupt();
            throw new IllegalStateException("Envio de WhatsApp interrumpido", exception);
        } catch (IOException exception) {
            throw new IllegalStateException("No se pudo conectar con WhatsApp Cloud", exception);
        }

        if (response.statusCode() < 200 || response.statusCode() >= 300) {
            throw new IllegalStateException(
                    "WhatsApp Cloud respondio con error "
                            + response.statusCode()
                            + ": "
                            + response.body()
            );
        }

        log.info("Mensaje de WhatsApp enviado correctamente a {}", toPhone);
        return true;
    }

    private String buildMessagesUrl() {
        return properties.getGraphBaseUrl().replaceAll("/+$", "")
                + "/"
                + properties.getApiVersion().replaceAll("^/+", "")
                + "/"
                + properties.getPhoneNumberId()
                + "/messages";
    }

    private boolean hasText(String value) {
        return value != null && !value.isBlank();
    }
}
