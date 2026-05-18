package com.navalgo.backend.notification;

import com.fasterxml.jackson.databind.JsonNode;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/webhooks/whatsapp")
public class WhatsAppWebhookController {

    private static final Logger log = LoggerFactory.getLogger(WhatsAppWebhookController.class);
    private final WhatsAppCloudProperties properties;
    private final WhatsAppCloudService whatsAppService;

    public WhatsAppWebhookController(WhatsAppCloudProperties properties, WhatsAppCloudService whatsAppService) {
        this.properties = properties;
        this.whatsAppService = whatsAppService;
    }

    // 1. Verificación obligatoria de Meta (al configurar el Webhook)
    @GetMapping
    public ResponseEntity<String> verifyWebhook(
            @RequestParam("hub.mode") String mode,
            @RequestParam("hub.verify_token") String token,
            @RequestParam("hub.challenge") String challenge) {

        if ("subscribe".equals(mode) && properties.getVerifyToken().equals(token)) {
            log.info("Webhook de WhatsApp verificado correctamente.");
            return ResponseEntity.ok(challenge);
        } else {
            return ResponseEntity.status(HttpStatus.FORBIDDEN).build();
        }
    }

    // 2. Recepción de mensajes del trabajador
    @PostMapping
    public ResponseEntity<Void> receiveMessage(@RequestBody JsonNode payload) {
        log.info("Payload recibido de WhatsApp: {}", payload.toString());

        try {
            JsonNode entries = payload.path("entry");
            for (JsonNode entry : entries) {
                JsonNode changes = entry.path("changes");
                for (JsonNode change : changes) {
                    JsonNode value = change.path("value");
                    JsonNode messages = value.path("messages");

                    if (messages != null && messages.isArray() && !messages.isEmpty()) {
                        JsonNode message = messages.get(0);
                        String fromPhone = message.path("from").asText();
                        String messageType = message.path("type").asText();

                        if ("text".equals(messageType)) {
                            String text = message.path("text").path("body").asText();
                            log.info("Mensaje de texto de {}: {}", fromPhone, text);
                            // Lógica de respuesta temporal:
                            if (text.toLowerCase().contains("si") || text.toLowerCase().contains("sí")) {
                                whatsAppService.sendTextMessage(fromPhone, "¡Genial! Mándame tu ubicación usando el clip de WhatsApp 📎 -> Ubicación.");
                            }
                        } else if ("location".equals(messageType)) {
                            double lat = message.path("location").path("latitude").asDouble();
                            double lng = message.path("location").path("longitude").asDouble();
                            log.info("Ubicación recibida de {}: Lat {}, Lng {}", fromPhone, lat, lng);
                            
                            whatsAppService.sendTextMessage(fromPhone, "Fichaje guardado correctamente con tu ubicación. ¡Gracias!");
                            // Aquí llamarías a tu TimeEntryService para guardar el fichaje
                        }
                    }
                }
            }
        } catch (Exception e) {
            log.error("Error procesando webhook de WhatsApp", e);
        }
        return ResponseEntity.ok().build(); // Siempre devolver 200 OK rápido a Meta
    }
}
