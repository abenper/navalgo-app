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

    public ResendEmailService(
            ObjectMapper objectMapper,
            @Value("${app.email.enabled:false}") boolean enabled,
            @Value("${app.email.resend.api-key:}") String apiKey,
            @Value("${app.email.resend.api-url:https://api.resend.com/emails}") String apiUrl,
            @Value("${app.email.from:Naval-GO <no-reply@naval-go.com>}") String fromAddress,
            @Value("${app.email.reply-to:}") String replyToAddress
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
    }

    public boolean sendRegistrationInvitation(String workerName,
                                              String workerEmail,
                                              String activationLink,
                                              String privacyPolicyLink) {
        if (!enabled) {
            return false;
        }
        if (apiKey == null || apiKey.isBlank()) {
            throw new IllegalStateException("El envio de emails esta activado, pero falta APP_EMAIL_RESEND_API_KEY");
        }

        Map<String, Object> payload = new LinkedHashMap<>();
        payload.put("from", fromAddress);
        payload.put("to", List.of(workerEmail));
        if (replyToAddress != null && !replyToAddress.isBlank()) {
            payload.put("reply_to", List.of(replyToAddress));
        }
        payload.put("subject", "Completa tu acceso a Naval-GO");
        payload.put("html", buildInvitationHtml(workerName, activationLink, privacyPolicyLink));
        payload.put("text", buildInvitationText(workerName, activationLink, privacyPolicyLink));

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
            throw new IllegalStateException("No se pudo preparar el email de invitacion", exception);
        }

        HttpResponse<String> response;
        try {
            response = httpClient.send(request, HttpResponse.BodyHandlers.ofString());
        } catch (InterruptedException exception) {
            Thread.currentThread().interrupt();
            throw new IllegalStateException("No se pudo enviar el email de invitacion", exception);
        } catch (IOException exception) {
            throw new IllegalStateException("No se pudo enviar el email de invitacion", exception);
        }

        if (response.statusCode() < 200 || response.statusCode() >= 300) {
            throw new IllegalStateException("Resend rechazo el email de invitacion: " + response.body());
        }
        return true;
    }

    private String buildInvitationHtml(String workerName, String activationLink, String privacyPolicyLink) {
        return """
                <div style="font-family:Arial,sans-serif;line-height:1.6;color:#17324d;">
                  <h2 style="margin-bottom:12px;">Bienvenido / Bienvenida a Naval-GO</h2>
                  <p>Hola, %s:</p>
                  <p>Tu cuenta ya ha sido creada en Naval-GO. Para activar tu acceso, completa el registro creando tu contraseña desde este enlace:</p>
                  <p style="margin:24px 0;">
                    <a href="%s" style="background:#0f5d8c;color:#ffffff;text-decoration:none;padding:12px 18px;border-radius:8px;display:inline-block;font-weight:700;">
                      Completar registro
                    </a>
                  </p>
                  <p>Si el botón no funciona, copia y pega esta URL en tu navegador:</p>
                  <p><a href="%s">%s</a></p>
                  <p>Tratamos tus datos para gestionar tu acceso y el uso de Naval-GO. Puedes consultar la Política de Privacidad aquí:</p>
                  <p><a href="%s">%s</a></p>
                  <p>Este correo se envía desde una dirección no monitorizada. Si respondes a este mensaje, tu respuesta no será atendida.</p>
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
                Completa tu registro creando tu contraseña aquí:
                %s

                Política de Privacidad:
                %s

                Este correo se envía desde una dirección no monitorizada.
                Si respondes a este mensaje, tu respuesta no será atendida.

                Si no esperabas este correo, puedes ignorarlo.
                """.formatted(workerName, activationLink, privacyPolicyLink);
    }

    private String escapeHtml(String value) {
        return value == null
                ? ""
                : value.replace("&", "&amp;")
                .replace("<", "&lt;")
                .replace(">", "&gt;")
                .replace("\"", "&quot;");
    }
}
