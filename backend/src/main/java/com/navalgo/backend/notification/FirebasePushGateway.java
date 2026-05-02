package com.navalgo.backend.notification;

import com.google.auth.oauth2.GoogleCredentials;
import com.google.firebase.FirebaseApp;
import com.google.firebase.FirebaseOptions;
import com.google.firebase.messaging.AndroidConfig;
import com.google.firebase.messaging.ApnsConfig;
import com.google.firebase.messaging.Aps;
import com.google.firebase.messaging.BatchResponse;
import com.google.firebase.messaging.FirebaseMessaging;
import com.google.firebase.messaging.FirebaseMessagingException;
import com.google.firebase.messaging.Message;
import com.google.firebase.messaging.MessagingErrorCode;
import com.google.firebase.messaging.MulticastMessage;
import com.google.firebase.messaging.Notification;
import com.google.firebase.messaging.SendResponse;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;

import java.io.ByteArrayInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Set;

@Component
public class FirebasePushGateway {

    private static final Logger log = LoggerFactory.getLogger(FirebasePushGateway.class);
    private static final String APP_NAME = "navalgo-backend";
    private static final String GOOGLE_APPLICATION_CREDENTIALS_ENV = "GOOGLE_APPLICATION_CREDENTIALS";
    private static final Path DEFAULT_DOCKER_SECRET_PATH = Path.of("/run/secrets/firebase-admin.json");

    private final FirebasePushProperties properties;

    private volatile FirebaseApp firebaseApp;
    private volatile boolean initializationAttempted;

    public FirebasePushGateway(FirebasePushProperties properties) {
        this.properties = properties;
    }

    public Set<String> send(List<String> tokens,
                            String title,
                            String message,
                            String actionRoute,
                            NotificationType type,
                            Long notificationId) {
        if (tokens == null || tokens.isEmpty()) {
            return Set.of();
        }

        FirebaseMessaging messaging = resolveMessaging();
        if (messaging == null) {
            return Set.of();
        }

        MulticastMessage pushMessage = MulticastMessage.builder()
                .addAllTokens(tokens)
                .putData("actionRoute", actionRoute == null ? "" : actionRoute)
                .putData("type", type == null ? NotificationType.INFO.name() : type.name())
                .putData("notificationId", notificationId == null ? "" : notificationId.toString())
                .setNotification(Notification.builder()
                        .setTitle(title)
                        .setBody(message)
                        .build())
                .setAndroidConfig(AndroidConfig.builder()
                        .setPriority(AndroidConfig.Priority.HIGH)
                        .build())
                .setApnsConfig(ApnsConfig.builder()
                        .setAps(Aps.builder().setSound("default").build())
                        .build())
                .build();

        try {
            BatchResponse response = messaging.sendEachForMulticast(pushMessage);
            return collectInvalidTokens(tokens, response.getResponses());
        } catch (FirebaseMessagingException ex) {
            log.warn("No se pudo enviar notificacion push por Firebase: {}", ex.getMessage());
            return Set.of();
        }
    }

    private Set<String> collectInvalidTokens(List<String> tokens, List<SendResponse> responses) {
        Set<String> invalidTokens = new LinkedHashSet<>();
        for (int index = 0; index < responses.size() && index < tokens.size(); index += 1) {
            SendResponse response = responses.get(index);
            if (response.isSuccessful()) {
                continue;
            }

            FirebaseMessagingException exception = response.getException();
            MessagingErrorCode errorCode = exception == null ? null : exception.getMessagingErrorCode();
            if (errorCode == MessagingErrorCode.UNREGISTERED || errorCode == MessagingErrorCode.INVALID_ARGUMENT) {
                invalidTokens.add(tokens.get(index));
            }
        }
        return invalidTokens;
    }

    private FirebaseMessaging resolveMessaging() {
        FirebaseApp app = resolveApp();
        return app == null ? null : FirebaseMessaging.getInstance(app);
    }

    private FirebaseApp resolveApp() {
        if (!properties.isEnabled()) {
            return null;
        }

        FirebaseApp localApp = firebaseApp;
        if (localApp != null) {
            return localApp;
        }

        synchronized (this) {
            if (firebaseApp != null) {
                return firebaseApp;
            }
            if (initializationAttempted) {
                return null;
            }

            initializationAttempted = true;

            try (InputStream credentialsStream = openCredentialsStream()) {
                if (credentialsStream == null) {
                    log.warn("Firebase push no esta configurado; se omite el envio push.");
                    return null;
                }

                FirebaseOptions options = FirebaseOptions.builder()
                        .setCredentials(GoogleCredentials.fromStream(credentialsStream))
                        .build();

                firebaseApp = FirebaseApp.getApps().stream()
                        .filter(app -> APP_NAME.equals(app.getName()))
                        .findFirst()
                        .orElseGet(() -> FirebaseApp.initializeApp(options, APP_NAME));
                return firebaseApp;
            } catch (IOException ex) {
                log.warn("No se pudo inicializar Firebase Admin SDK: {}", ex.getMessage());
                return null;
            }
        }
    }

    private InputStream openCredentialsStream() throws IOException {
        if (properties.getServiceAccountJson() != null && !properties.getServiceAccountJson().isBlank()) {
            return new ByteArrayInputStream(properties.getServiceAccountJson().getBytes(StandardCharsets.UTF_8));
        }
        if (properties.getServiceAccountPath() != null && !properties.getServiceAccountPath().isBlank()) {
            return Files.newInputStream(Path.of(properties.getServiceAccountPath().trim()));
        }
        String googleApplicationCredentials = System.getenv(GOOGLE_APPLICATION_CREDENTIALS_ENV);
        if (googleApplicationCredentials != null && !googleApplicationCredentials.isBlank()) {
            return Files.newInputStream(Path.of(googleApplicationCredentials.trim()));
        }
        if (Files.exists(DEFAULT_DOCKER_SECRET_PATH)) {
            return Files.newInputStream(DEFAULT_DOCKER_SECRET_PATH);
        }
        return null;
    }
}
