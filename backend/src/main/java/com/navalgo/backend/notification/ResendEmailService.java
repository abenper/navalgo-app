package com.navalgo.backend.notification;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Service;

import java.io.IOException;
import java.math.BigDecimal;
import java.net.URI;
import java.net.URLEncoder;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
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
            @Value("${app.frontend.base-url:https://app.naval-go.com}") String frontendBaseUrl
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

    public boolean sendBudgetNotification(String clientName,
                                          String clientEmail,
                                          String budgetTitle,
                                          String vesselName,
                                          BigDecimal amount,
                                          String currency,
                                          String pdfUrl,
                                          boolean clientHasAccount) {
        Map<String, Object> payload = new LinkedHashMap<>();
        payload.put("from", fromAddress);
        payload.put("to", List.of(clientEmail));
        payload.put("subject", sanitizeSubject("Nuevo presupuesto disponible"));
        payload.put("html", buildBudgetNotificationHtml(
                clientName, clientEmail, budgetTitle, vesselName, amount, currency, pdfUrl, clientHasAccount
        ));
        payload.put("text", buildBudgetNotificationText(
                clientName, clientEmail, budgetTitle, vesselName, amount, currency, pdfUrl, clientHasAccount
        ));
        return sendEmail(payload, "No se pudo enviar el email de presupuesto");
    }

    public boolean sendBudgetDecisionNotification(String workerName,
                                                  String workerEmail,
                                                  String clientName,
                                                  String vesselName,
                                                  String budgetTitle,
                                                  String statusLabel,
                                                  String clientObservations) {
        Map<String, Object> payload = new LinkedHashMap<>();
        payload.put("from", fromAddress);
        payload.put("to", List.of(workerEmail));
        payload.put("subject", sanitizeSubject("Presupuesto " + statusLabel.toLowerCase()));
        payload.put("html", buildBudgetDecisionNotificationHtml(
                workerName,
                clientName,
                vesselName,
                budgetTitle,
                statusLabel,
                clientObservations
        ));
        payload.put("text", buildBudgetDecisionNotificationText(
                workerName,
                clientName,
                vesselName,
                budgetTitle,
                statusLabel,
                clientObservations
        ));
        return sendEmail(payload, "No se pudo enviar el email de respuesta del presupuesto");
    }

    public boolean sendEmailVerification(String clientName,
                                         String clientEmail,
                                         String verificationLink,
                                         String privacyPolicyLink) {
        Map<String, Object> payload = new LinkedHashMap<>();
        payload.put("from", fromAddress);
        payload.put("to", List.of(clientEmail));
        payload.put("subject", "Confirma tu cuenta");
        payload.put("html", buildEmailVerificationHtml(clientName, verificationLink, privacyPolicyLink));
        payload.put("text", buildEmailVerificationText(clientName, verificationLink, privacyPolicyLink));
        return sendEmail(payload, "No se pudo enviar el email de verificacion");
    }

    public boolean sendPasswordReset(String accountName,
                                     String accountEmail,
                                     String resetLink) {
        Map<String, Object> payload = new LinkedHashMap<>();
        payload.put("from", fromAddress);
        payload.put("to", List.of(accountEmail));
        payload.put("subject", "Restablece tu contrasena");
        payload.put("html", buildPasswordResetHtml(accountName, resetLink));
        payload.put("text", buildPasswordResetText(accountName, resetLink));
        return sendEmail(payload, "No se pudo enviar el email para restablecer la contrasena");
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

    private String buildEmailVerificationHtml(String clientName, String verificationLink, String privacyPolicyLink) {
        return """
                <div style="font-family:Arial,sans-serif;line-height:1.6;color:#17324d;">
                  <h2 style="margin-bottom:12px;">Confirma tu cuenta</h2>
                  <p>Hola, %s:</p>
                  <p>Hemos recibido tu solicitud de alta en Naval-GO. Para activar tu cuenta, confirma tu correo desde este enlace:</p>
                  <p style="margin:24px 0;">
                    <a href="%s" style="background:#0f5d8c;color:#ffffff;text-decoration:none;padding:12px 18px;border-radius:8px;display:inline-block;font-weight:700;">
                      Confirmar correo electronico
                    </a>
                  </p>
                  <p>Si el boton no funciona, copia y pega esta URL en tu navegador:</p>
                  <p><a href="%s">%s</a></p>
                  <p>Puedes consultar la Politica de Privacidad aqui:</p>
                  <p><a href="%s">%s</a></p>
                  <p>Si no has creado esta cuenta, puedes ignorar este mensaje.</p>
                  <p>Equipo Naval-GO</p>
                </div>
                """.formatted(
                escapeHtml(clientName),
                verificationLink,
                verificationLink,
                verificationLink,
                privacyPolicyLink,
                privacyPolicyLink
        );
    }

    private String buildEmailVerificationText(String clientName, String verificationLink, String privacyPolicyLink) {
        return """
                Hola, %s:

                Hemos recibido tu solicitud de alta en Naval-GO.
                Confirma tu correo aqui:
                %s

                Politica de Privacidad:
                %s
                """.formatted(clientName, verificationLink, privacyPolicyLink);
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

    private String buildBudgetNotificationHtml(String clientName,
                                               String clientEmail,
                                               String budgetTitle,
                                               String vesselName,
                                               BigDecimal amount,
                                               String currency,
                                               String pdfUrl,
                                               boolean clientHasAccount) {
        String formattedAmount = formatAmount(amount, currency);
        String signupUrl = buildClientSignupUrl(clientName, clientEmail);
        String accountHint = clientHasAccount
                ? """
                  <p>En breve podras aceptarlo o rechazarlo directamente desde tu area de cliente. Mientras tanto, ya tienes el documento disponible en el enlace anterior.</p>
                  """
                : """
                  <p>Tu presupuesto ya te esta esperando en Naval-GO. Si aun no tienes cuenta, entra en la plataforma y pulsa <strong>Crear cuenta</strong> usando este mismo correo: <strong>%s</strong>.</p>
                  <p style="margin:20px 0;">
                    <a href="%s" style="background:#17324d;color:#ffffff;text-decoration:none;padding:12px 18px;border-radius:8px;display:inline-block;font-weight:700;">
                      Crear cuenta
                    </a>
                  </p>
                  """.formatted(escapeHtml(clientEmailSafe(clientName, clientEmail)), escapeHtmlAttribute(signupUrl));
        return """
                <div style="font-family:Arial,sans-serif;line-height:1.6;color:#17324d;">
                  <h2 style="margin-bottom:12px;">Nuevo presupuesto disponible</h2>
                  <p>Hola, %s:</p>
                  <p>Ya tienes disponible un nuevo presupuesto en Naval-GO para la embarcacion <strong>%s</strong>.</p>
                  <p><strong>%s</strong></p>
                  <p>Importe: <strong>%s</strong></p>
                  <p style="margin:24px 0;">
                    <a href="%s" style="background:#0f5d8c;color:#ffffff;text-decoration:none;padding:12px 18px;border-radius:8px;display:inline-block;font-weight:700;">
                      Ver PDF del presupuesto
                    </a>
                  </p>
                  %s
                  <p>Equipo Naval-GO</p>
                </div>
                """.formatted(
                escapeHtml(clientName),
                escapeHtml(vesselName),
                escapeHtml(budgetTitle),
                escapeHtml(formattedAmount),
                escapeHtmlAttribute(pdfUrl),
                accountHint
        );
    }

    private String buildBudgetNotificationText(String clientName,
                                               String clientEmail,
                                               String budgetTitle,
                                               String vesselName,
                                               BigDecimal amount,
                                               String currency,
                                               String pdfUrl,
                                               boolean clientHasAccount) {
        String signupUrl = buildClientSignupUrl(clientName, clientEmail);
        String accountHint = clientHasAccount
                ? "En breve podras aceptarlo o rechazarlo directamente desde tu area de cliente."
                : """
                Tu presupuesto ya te esta esperando en Naval-GO.
                Si aun no tienes cuenta, entra en la plataforma y pulsa Crear cuenta usando este mismo correo: %s.

                Crear cuenta:
                %s
                """.formatted(clientEmailSafe(clientName, clientEmail), signupUrl);
        return """
                Hola, %s:

                Ya tienes disponible un nuevo presupuesto en Naval-GO para la embarcacion %s.
                %s
                Importe: %s

                Ver PDF del presupuesto:
                %s
                
                %s
                """.formatted(
                clientName,
                vesselName,
                budgetTitle,
                formatAmount(amount, currency),
                pdfUrl,
                accountHint
        );
    }

    private String buildBudgetDecisionNotificationHtml(String workerName,
                                                       String clientName,
                                                       String vesselName,
                                                       String budgetTitle,
                                                       String statusLabel,
                                                       String clientObservations) {
        String appUrl = normalizeFrontendBaseUrl();
        String observationsBlock = clientObservations == null || clientObservations.isBlank()
                ? ""
                : """
                  <p><strong>Observaciones del cliente:</strong><br>%s</p>
                  """.formatted(escapeHtml(clientObservations));
        return """
                <div style="font-family:Arial,sans-serif;line-height:1.6;color:#17324d;">
                  <h2 style="margin-bottom:12px;">Presupuesto %s</h2>
                  <p>Hola, %s:</p>
                  <p>El cliente <strong>%s</strong> ha marcado como <strong>%s</strong> el presupuesto de la embarcacion <strong>%s</strong>.</p>
                  <p><strong>%s</strong></p>
                  %s
                  <p style="margin:24px 0;">
                    <a href="%s" style="background:#0f5d8c;color:#ffffff;text-decoration:none;padding:12px 18px;border-radius:8px;display:inline-block;font-weight:700;">
                      Revisar presupuesto
                    </a>
                  </p>
                  <p>Equipo Naval-GO</p>
                </div>
                """.formatted(
                escapeHtml(statusLabel.toLowerCase()),
                escapeHtml(workerName),
                escapeHtml(clientName),
                escapeHtml(statusLabel.toLowerCase()),
                escapeHtml(vesselName),
                escapeHtml(budgetTitle),
                observationsBlock,
                escapeHtmlAttribute(appUrl)
        );
    }

    private String buildBudgetDecisionNotificationText(String workerName,
                                                       String clientName,
                                                       String vesselName,
                                                       String budgetTitle,
                                                       String statusLabel,
                                                       String clientObservations) {
        String observationsBlock = clientObservations == null || clientObservations.isBlank()
                ? ""
                : """

                Observaciones del cliente:
                %s
                """.formatted(clientObservations);
        return """
                Hola, %s:

                El cliente %s ha marcado como %s el presupuesto de la embarcacion %s.
                %s
                %s

                Revisar presupuesto:
                %s
                """.formatted(
                workerName,
                clientName,
                statusLabel.toLowerCase(),
                vesselName,
                budgetTitle,
                observationsBlock,
                normalizeFrontendBaseUrl()
        );
    }

    private String clientEmailSafe(String fallbackName, String email) {
        if (email != null && !email.isBlank()) {
            return email;
        }
        return fallbackName == null || fallbackName.isBlank() ? "tu correo" : fallbackName;
    }

    private String buildClientSignupUrl(String clientName, String clientEmail) {
        String baseUrl = normalizeFrontendBaseUrl();
        String separator = baseUrl.contains("?") ? "&" : "?";
        return baseUrl
                + separator
                + "screen=create-account"
                + "&email=" + urlEncode(clientEmail)
                + "&name=" + urlEncode(clientName);
    }

    private String buildPasswordResetHtml(String accountName, String resetLink) {
        return """
                <div style="font-family:Arial,sans-serif;line-height:1.6;color:#17324d;">
                  <h2 style="margin-bottom:12px;">Restablece tu contrasena</h2>
                  <p>Hola, %s:</p>
                  <p>Hemos recibido una solicitud para cambiar la contrasena de tu cuenta en Naval-GO.</p>
                  <p style="margin:24px 0;">
                    <a href="%s" style="background:#0f5d8c;color:#ffffff;text-decoration:none;padding:12px 18px;border-radius:8px;display:inline-block;font-weight:700;">
                      Cambiar contrasena
                    </a>
                  </p>
                  <p>Si el boton no funciona, copia y pega esta URL en tu navegador:</p>
                  <p><a href="%s">%s</a></p>
                  <p>Si no has solicitado este cambio, puedes ignorar este mensaje.</p>
                  <p>Equipo Naval-GO</p>
                </div>
                """.formatted(
                escapeHtml(accountName),
                resetLink,
                resetLink,
                resetLink
        );
    }

    private String buildPasswordResetText(String accountName, String resetLink) {
        return """
                Hola, %s:

                Hemos recibido una solicitud para cambiar la contrasena de tu cuenta en Naval-GO.
                Usa este enlace:
                %s

                Si no has solicitado este cambio, puedes ignorar este mensaje.
                """.formatted(accountName, resetLink);
    }

    private String normalizeFrontendBaseUrl() {
        if (frontendBaseUrl == null || frontendBaseUrl.isBlank()) {
            return "https://app.naval-go.com";
        }
        return frontendBaseUrl.trim();
    }

    private String urlEncode(String value) {
        return URLEncoder.encode(value == null ? "" : value, StandardCharsets.UTF_8);
    }

    private String sanitizeSubject(String title) {
        if (title == null || title.isBlank()) {
            return "Notificacion";
        }
        return title.replaceAll("\\s+", " ").trim();
    }

    private String formatAmount(BigDecimal amount, String currency) {
        if (amount == null) {
            return "Pendiente de definir";
        }
        String normalizedCurrency = (currency == null || currency.isBlank()) ? "EUR" : currency.trim().toUpperCase();
        return amount.stripTrailingZeros().toPlainString() + " " + normalizedCurrency;
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
