package com.navalgo.backend.notification;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.beans.factory.annotation.Value;
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
import java.util.List;
import java.util.Map;

@Service
public class ResendEmailService {

    private final ObjectMapper objectMapper;
    private final HttpClient httpClient;
    private final boolean enabled;
    private final String apiKey;
    private final String apiUrl;
    private final String fromAddress;
    private final String replyToAddress;
    private final String frontendBaseUrl;

    public ResendEmailService(
            ObjectMapper objectMapper,
            @Value("${app.email.enabled:false}") boolean enabled,
            @Value("${app.email.resend.api-key:}") String apiKey,
            @Value("${app.email.resend.api-url:https://api.resend.com/emails}") String apiUrl,
            @Value("${app.email.from:Naval-GO <notificaciones@naval-go.com>}") String fromAddress,
            @Value("${app.email.reply-to:}") String replyToAddress,
            @Value("${app.frontend.base-url:https://naval-go.com}") String frontendBaseUrl
    ) {
        this.objectMapper = objectMapper;
        this.httpClient = HttpClient.newBuilder()
                .connectTimeout(Duration.ofSeconds(10))
                .build();
        this.enabled = enabled;
        this.apiKey = apiKey;
        this.apiUrl = apiUrl;
        this.fromAddress = fromAddress;
        this.replyToAddress = replyToAddress;
        this.frontendBaseUrl = frontendBaseUrl;
    }

    public boolean sendRegistrationInvitation(String workerName,
                                              String workerEmail,
                                              String activationLink,
                                              String privacyPolicyLink) {
        Map<String, Object> payload = new LinkedHashMap<>();
        payload.put("from", fromAddress);
        payload.put("to", List.of(workerEmail));
        payload.put("subject", "Completa tu acceso a Naval-GO");
        payload.put("html", buildInvitationHtml(workerName, activationLink, privacyPolicyLink));
        payload.put("text", buildInvitationText(workerName, activationLink, privacyPolicyLink));
        return sendEmail(payload, "No se pudo enviar el email de invitacion");
    }

    public boolean sendNotificationFallback(String workerName,
                                            String workerEmail,
                                            String title,
                                            String message) {
        Map<String, Object> payload = new LinkedHashMap<>();
        payload.put("from", fromAddress);
        payload.put("to", List.of(workerEmail));
        payload.put("subject", sanitizeSubject(title));
        payload.put("html", buildNotificationFallbackHtml(workerName, title, message));
        payload.put("text", buildNotificationFallbackText(workerName, title, message));
        return sendEmail(payload, "No se pudo enviar el email de notificacion");
    }

    private boolean sendEmail(Map<String, Object> payload, String failureMessage) {
        if (!enabled) {
            return false;
        }
        if (apiKey == null || apiKey.isBlank()) {
            throw new IllegalStateException("El envio de emails esta activado, pero falta APP_EMAIL_RESEND_API_KEY");
        }
        if (replyToAddress != null && !replyToAddress.isBlank()) {
            payload.put("reply_to", List.of(replyToAddress));
        }

        HttpRequest request;
        try {
            request = HttpRequest.newBuilder()
                    .uri(URI.create(apiUrl))
                    .timeout(Duration.ofSeconds(15))
                    .header(HttpHeaders.AUTHORIZATION, "Bearer " + apiKey)
                    .header(HttpHeaders.CONTENT_TYPE, MediaType.APPLICATION_JSON_VALUE)
                    .POST(HttpRequest.BodyPublishers.ofString(objectMapper.writeValueAsString(payload)))
                    .build();
        } catch (JsonProcessingException exception) {
            throw new IllegalStateException(failureMessage, exception);
        }

        HttpResponse<String> response;
        try {
            response = httpClient.send(request, HttpResponse.BodyHandlers.ofString());
        } catch (InterruptedException exception) {
            Thread.currentThread().interrupt();
            throw new IllegalStateException(failureMessage, exception);
        } catch (IOException exception) {
            throw new IllegalStateException(failureMessage, exception);
        }

        if (response.statusCode() < 200 || response.statusCode() >= 300) {
            throw new IllegalStateException(failureMessage + ": " + response.body());
        }
        return true;
    }

    private String buildInvitationHtml(String workerName, String activationLink, String privacyPolicyLink) {
        return """
                <div style="font-family:Arial,sans-serif;line-height:1.6;color:#17324d;">
                  <h2 style="margin-bottom:12px;">Bienvenido / Bienvenida a Naval-GO</h2>
                  <p>Hola, %s:</p>
                  <p>Tu cuenta ya ha sido creada en Naval-GO. Para activar tu acceso, completa el registro creando tu contrase\u00f1a desde este enlace:</p>
                  <p style="margin:24px 0;">
                    <a href="%s" style="background:#0f5d8c;color:#ffffff;text-decoration:none;padding:12px 18px;border-radius:8px;display:inline-block;font-weight:700;">
                      Completar registro
                    </a>
                  </p>
                  <p>Si el bot\u00f3n no funciona, copia y pega esta URL en tu navegador:</p>
                  <p><a href="%s">%s</a></p>
                  <p>Tratamos tus datos para gestionar tu acceso y el uso de Naval-GO. Puedes consultar la Pol\u00edtica de Privacidad aqu\u00ed:</p>
                  <p><a href="%s">%s</a></p>
                  <p>Este correo se env\u00eda desde una direcci\u00f3n no monitorizada. Si respondes a este mensaje, tu respuesta no ser\u00e1 atendida.</p>
                  <p>Si no esperabas este correo, puedes ignorarlo.</p>
                  <p>Equipo Naval-GO</p>
                </div>
                """.formatted(
                escapeHtml(workerName),
                activationLink,
                activationLink,
                activationLink,
                privacyPolicyLink,
                privacyPolicyLink
        );
    }

    private String buildInvitationText(String workerName, String activationLink, String privacyPolicyLink) {
        return """
                Hola, %s:

                Tu cuenta ya ha sido creada en Naval-GO.
                Completa tu registro creando tu contrase\u00f1a aqu\u00ed:
                %s

                Pol\u00edtica de Privacidad:
                %s

                Este correo se env\u00eda desde una direcci\u00f3n no monitorizada.
                Si respondes a este mensaje, tu respuesta no ser\u00e1 atendida.

                Si no esperabas este correo, puedes ignorarlo.
                """.formatted(workerName, activationLink, privacyPolicyLink);
    }

    private String buildNotificationFallbackHtml(String workerName, String title, String message) {
        String appUrl = normalizeFrontendBaseUrl();
        return """
                <div style="font-family:Arial,sans-serif;line-height:1.6;color:#17324d;">
                  <h2 style="margin-bottom:12px;">Nueva notificaci\u00f3n</h2>
                  <p>Hola, %s:</p>
                  <p><strong>%s</strong></p>
                  <p>%s</p>
                  <p style="margin:24px 0;">
                    <a href="%s" style="background:#0f5d8c;color:#ffffff;text-decoration:none;padding:12px 18px;border-radius:8px;display:inline-block;font-weight:700;">
                      Abrir Naval-GO
                    </a>
                  </p>
                  <p>Este correo se env\u00eda desde una direcci\u00f3n no monitorizada. Si respondes a este mensaje, tu respuesta no ser\u00e1 atendida.</p>
                  <p>Equipo Naval-GO</p>
                </div>
                """.formatted(
                escapeHtml(workerName),
                escapeHtml(title),
                escapeHtml(message),
                escapeHtmlAttribute(appUrl)
        );
    }

    private String buildNotificationFallbackText(String workerName, String title, String message) {
        return """
                Hola, %s:

                %s
                %s

                Abrir Naval-GO:
                %s

                Este correo se env\u00eda desde una direcci\u00f3n no monitorizada.
                Si respondes a este mensaje, tu respuesta no ser\u00e1 atendida.
                """.formatted(workerName, title, message, normalizeFrontendBaseUrl());
    }

    private String normalizeFrontendBaseUrl() {
        if (frontendBaseUrl == null || frontendBaseUrl.isBlank()) {
            return "https://naval-go.com";
        }
        return frontendBaseUrl.trim();
    }

    private String sanitizeSubject(String title) {
        if (title == null || title.isBlank()) {
            return "Notificacion";
        }
        return title.replaceAll("\\s+", " ").trim();
    }

    private String escapeHtml(String value) {
        return value == null
                ? ""
                : value.replace("&", "&amp;")
                .replace("<", "&lt;")
                .replace(">", "&gt;")
                .replace("\"", "&quot;");
    }

    private String escapeHtmlAttribute(String value) {
        return escapeHtml(value).replace("'", "&#39;");
    }
}
