package com.navalgo.backend.notification;

import com.navalgo.backend.worker.Worker;
import com.navalgo.backend.worker.WorkerRepository;
import jakarta.persistence.EntityNotFoundException;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.time.Instant;
import java.util.List;

@RestController
@RequestMapping("/api/push-debug")
public class PushDebugController {

    private final PushNotificationService pushNotificationService;
    private final NotificationService notificationService;
    private final WorkerRepository workerRepository;

    public PushDebugController(PushNotificationService pushNotificationService,
                               NotificationService notificationService,
                               WorkerRepository workerRepository) {
        this.pushNotificationService = pushNotificationService;
        this.notificationService = notificationService;
        this.workerRepository = workerRepository;
    }

    @GetMapping("/status")
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<PushDebugStatusDto> status() {
        return ResponseEntity.ok(pushNotificationService.getDebugStatus());
    }

    @GetMapping("/tokens")
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<List<PushDebugTokenDto>> tokens() {
        return ResponseEntity.ok(pushNotificationService.listDebugTokens());
    }

    @PostMapping("/send-self-test")
    @PreAuthorize("hasAnyRole('ADMIN','WORKER')")
    public ResponseEntity<Void> sendSelfTest(Authentication authentication) {
        Worker worker = workerRepository.findByEmailIgnoreCase(authentication.getName())
                .orElseThrow(() -> new EntityNotFoundException("Usuario no encontrado"));

        notificationService.notifyWorker(
                worker.getId(),
                "Push de prueba",
                "Prueba de notificacion enviada el " + Instant.now(),
                "PANEL",
                NotificationType.INFO
        );

        return ResponseEntity.noContent().build();
    }
}
