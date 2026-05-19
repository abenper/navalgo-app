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
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
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
        Map<String, Object> textNode = new LinkedHashMap<>();
        textNode.put("preview_url", false);
        textNode.put("body", message.trim());

        Map<String, Object> payload = new LinkedHashMap<>();
        payload.put("messaging_product", "whatsapp");
        payload.put("to", toPhone.trim());
        payload.put("type", "text");
        payload.put("text", textNode);
        return sendPayload(toPhone, message, payload);
    }

    public boolean sendQuickReplyButtonMessage(String toPhone,
                                               String message,
                                               String buttonId,
                                               String buttonTitle) {
        return sendQuickReplyButtonsMessage(
                toPhone,
                message,
                List.of(new QuickReplyButton(buttonId, buttonTitle))
        );
    }

    public boolean sendQuickReplyButtonsMessage(String toPhone,
                                                String message,
                                                List<QuickReplyButton> buttons) {
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

        List<QuickReplyButton> validButtons = buttons == null
                ? List.of()
                : buttons.stream()
                .filter(button -> button != null && hasText(button.id()) && hasText(button.title()))
                .limit(3)
                .toList();

        if (validButtons.isEmpty()) {
            return sendTextMessage(toPhone, message);
        }

        Map<String, Object> bodyNode = new LinkedHashMap<>();
        bodyNode.put("text", message.trim());

        Map<String, Object> actionNode = new LinkedHashMap<>();
        actionNode.put(
                "buttons",
                validButtons.stream()
                        .map(button -> {
                            Map<String, Object> replyNode = new LinkedHashMap<>();
                            replyNode.put("id", button.id().trim());
                            replyNode.put("title", button.title().trim());

                            Map<String, Object> buttonNode = new LinkedHashMap<>();
                            buttonNode.put("type", "reply");
                            buttonNode.put("reply", replyNode);
                            return buttonNode;
                        })
                        .toList()
        );

        Map<String, Object> interactiveNode = new LinkedHashMap<>();
        interactiveNode.put("type", "button");
        interactiveNode.put("body", bodyNode);
        interactiveNode.put("action", actionNode);

        Map<String, Object> payload = new LinkedHashMap<>();
        payload.put("messaging_product", "whatsapp");
        payload.put("to", toPhone.trim());
        payload.put("type", "interactive");
        payload.put("interactive", interactiveNode);
        return sendPayload(toPhone, message, payload);
    }

    public boolean sendMissingClockInReminderTemplate(String toPhone,
                                                      List<String> bodyParameters,
                                                      String quickReplyPayload) {
        if (!properties.hasMissingClockInTemplateConfigured()) {
            return false;
        }

        Map<String, Object> languageNode = new LinkedHashMap<>();
        languageNode.put("code", properties.getMissingClockInTemplateLanguageCode());

        Map<String, Object> templateNode = new LinkedHashMap<>();
        templateNode.put("name", properties.getMissingClockInTemplateName());
        templateNode.put("language", languageNode);

        List<Map<String, Object>> components = new ArrayList<>();
        if (bodyParameters != null && !bodyParameters.isEmpty()) {
            List<Map<String, Object>> parameters = bodyParameters.stream()
                    .filter(this::hasText)
                    .map(value -> {
                        Map<String, Object> parameterNode = new LinkedHashMap<>();
                        parameterNode.put("type", "text");
                        parameterNode.put("text", value.trim());
                        return parameterNode;
                    })
                    .toList();
            if (!parameters.isEmpty()) {
                Map<String, Object> bodyComponentNode = new LinkedHashMap<>();
                bodyComponentNode.put("type", "body");
                bodyComponentNode.put("parameters", parameters);
                components.add(bodyComponentNode);
            }
        }

        if (hasText(quickReplyPayload)) {
            Map<String, Object> buttonParameterNode = new LinkedHashMap<>();
            buttonParameterNode.put("type", "payload");
            buttonParameterNode.put("payload", quickReplyPayload.trim());

            Map<String, Object> buttonComponentNode = new LinkedHashMap<>();
            buttonComponentNode.put("type", "button");
            buttonComponentNode.put("sub_type", "quick_reply");
            buttonComponentNode.put("index", "0");
            buttonComponentNode.put("parameters", java.util.List.of(buttonParameterNode));
            components.add(buttonComponentNode);
        }

        if (!components.isEmpty()) {
            templateNode.put("components", components);
        }

        Map<String, Object> payload = new LinkedHashMap<>();
        payload.put("messaging_product", "whatsapp");
        payload.put("to", toPhone.trim());
        payload.put("type", "template");
        payload.put("template", templateNode);
        return sendPayload(toPhone, "template:" + properties.getMissingClockInTemplateName(), payload);
    }

    public record QuickReplyButton(String id, String title) {
    }

    private boolean sendPayload(String toPhone, String message, Map<String, Object> payload) {
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
