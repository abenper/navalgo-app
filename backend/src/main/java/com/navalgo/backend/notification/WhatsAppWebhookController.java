package com.navalgo.backend.notification;

import com.fasterxml.jackson.databind.JsonNode;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/webhooks/whatsapp")
public class WhatsAppWebhookController {

    private static final Logger log = LoggerFactory.getLogger(WhatsAppWebhookController.class);

    private final WhatsAppCloudProperties properties;
    private final WhatsAppClockInFlowService whatsAppClockInFlowService;

    public WhatsAppWebhookController(WhatsAppCloudProperties properties,
                                     WhatsAppClockInFlowService whatsAppClockInFlowService) {
        this.properties = properties;
        this.whatsAppClockInFlowService = whatsAppClockInFlowService;
    }

    @GetMapping
    public ResponseEntity<String> verifyWebhook(
            @RequestParam("hub.mode") String mode,
            @RequestParam("hub.verify_token") String token,
            @RequestParam("hub.challenge") String challenge) {

        if ("subscribe".equals(mode) && properties.getVerifyToken().equals(token)) {
            log.info("Webhook de WhatsApp verificado correctamente.");
            return ResponseEntity.ok(challenge);
        }
        return ResponseEntity.status(HttpStatus.FORBIDDEN).build();
    }

    @PostMapping
    public ResponseEntity<Void> receiveMessage(@RequestBody JsonNode payload) {
        log.info("Payload recibido de WhatsApp");

        try {
            JsonNode entries = payload.path("entry");
            for (JsonNode entry : entries) {
                JsonNode changes = entry.path("changes");
                for (JsonNode change : changes) {
                    JsonNode messages = change.path("value").path("messages");
                    if (messages == null || !messages.isArray() || messages.isEmpty()) {
                        continue;
                    }

                    for (JsonNode message : messages) {
                        whatsAppClockInFlowService.handleIncomingMessage(message);
                    }
                }
            }
        } catch (Exception exception) {
            log.error("Error procesando webhook de WhatsApp", exception);
        }

        return ResponseEntity.ok().build();
    }
}
