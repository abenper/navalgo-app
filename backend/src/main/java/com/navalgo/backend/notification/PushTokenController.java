package com.navalgo.backend.notification;

import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/push-tokens")
public class PushTokenController {

    private final PushNotificationService pushNotificationService;

    public PushTokenController(PushNotificationService pushNotificationService) {
        this.pushNotificationService = pushNotificationService;
    }

    @PostMapping("/register")
    @PreAuthorize("hasAnyRole('ADMIN','WORKER')")
    public ResponseEntity<Void> register(Authentication authentication,
                                         @Valid @RequestBody PushTokenRegistrationRequest request) {
        pushNotificationService.registerToken(authentication.getName(), request);
        return ResponseEntity.noContent().build();
    }

    @PostMapping("/unregister")
    @PreAuthorize("hasAnyRole('ADMIN','WORKER')")
    public ResponseEntity<Void> unregister(Authentication authentication,
                                           @Valid @RequestBody PushTokenUnregistrationRequest request) {
        pushNotificationService.unregisterToken(authentication.getName(), request);
        return ResponseEntity.noContent().build();
    }
}