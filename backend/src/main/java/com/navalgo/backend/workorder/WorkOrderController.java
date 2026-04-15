package com.navalgo.backend.workorder;

import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.multipart.MultipartFile;
import org.springframework.web.bind.annotation.*;

import java.time.Instant;
import java.util.List;

@RestController
@RequestMapping("/api/work-orders")
public class WorkOrderController {

    private final WorkOrderService service;
    private final WorkOrderMediaService mediaService;

    public WorkOrderController(WorkOrderService service,
                               WorkOrderMediaService mediaService) {
        this.service = service;
        this.mediaService = mediaService;
    }

    @GetMapping
    @PreAuthorize("hasAnyRole('ADMIN','WORKER')")
    public ResponseEntity<List<WorkOrderDto>> list(@RequestParam(required = false) Long workerId,
                                                   Authentication authentication) {
        boolean isAdmin = authentication.getAuthorities().stream()
                .anyMatch(a -> "ROLE_ADMIN".equals(a.getAuthority()));

        if (isAdmin) {
            if (workerId != null) {
                return ResponseEntity.ok(service.findByWorker(workerId));
            }
            return ResponseEntity.ok(service.findAll());
        }

        Long currentWorkerId = service.findWorkerIdByEmail(authentication.getName());
        if (workerId != null && !workerId.equals(currentWorkerId)) {
            throw new AccessDeniedException("Solo puedes ver tus propios partes");
        }
        return ResponseEntity.ok(service.findByWorker(currentWorkerId));
    }

    @PostMapping
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<WorkOrderDto> create(@RequestBody @Valid CreateWorkOrderRequest request) {
        return ResponseEntity.ok(service.create(request));
    }

    @PatchMapping("/{id}/status")
    @PreAuthorize("hasAnyRole('ADMIN','WORKER')")
    public ResponseEntity<WorkOrderDto> updateStatus(@PathVariable Long id,
                                                     @RequestBody @Valid UpdateWorkOrderStatusRequest request,
                                                     Authentication authentication) {
        return ResponseEntity.ok(service.updateStatus(id, request, authentication.getName()));
    }

    @PatchMapping("/{id}")
    @PreAuthorize("hasAnyRole('ADMIN','WORKER')")
    public ResponseEntity<WorkOrderDto> updateWorkOrder(@PathVariable Long id,
                                                        @RequestBody @Valid UpdateWorkOrderRequest request,
                                                        Authentication authentication) {
        return ResponseEntity.ok(service.updateWorkOrder(id, request, authentication.getName()));
    }

    @DeleteMapping("/{id}/attachments/{attachmentId}")
    @PreAuthorize("hasAnyRole('ADMIN','WORKER')")
    public ResponseEntity<WorkOrderDto> deleteAttachment(@PathVariable Long id,
                                                         @PathVariable Long attachmentId,
                                                         Authentication authentication) {
        return ResponseEntity.ok(service.deleteAttachment(id, attachmentId, authentication.getName()));
    }

    @PostMapping("/uploads")
    @PreAuthorize("hasAnyRole('ADMIN','WORKER')")
    public ResponseEntity<UploadedAttachmentDto> uploadAttachment(@RequestParam("file") MultipartFile file,
                                                                  @RequestParam(required = false) Double latitude,
                                                                  @RequestParam(required = false) Double longitude,
                                                                  @RequestParam(required = false) Instant capturedAt,
                                                                  @RequestHeader(value = "X-Client-Platform", required = false) String clientPlatform,
                                                                  Authentication authentication) {
        if (clientPlatform == null || !"web".equalsIgnoreCase(clientPlatform)) {
            throw new IllegalArgumentException("La subida multimedia solo esta permitida desde la web");
        }
        return ResponseEntity.ok(mediaService.uploadMedia(file, latitude, longitude, capturedAt, authentication.getName()));
    }

    @PostMapping(value = "/{id}/sign", consumes = "multipart/form-data")
    @PreAuthorize("hasAnyRole('ADMIN','WORKER')")
    public ResponseEntity<WorkOrderDto> signWorkOrder(
            @PathVariable Long id,
            @RequestParam("signatureFile") MultipartFile signatureFile,
            @RequestParam(value = "proofFile", required = false) List<MultipartFile> proofFiles,
            @RequestParam(required = false) Double latitude,
            @RequestParam(required = false) Double longitude,
            Authentication authentication) {

        String email = authentication.getName();
        Instant now = Instant.now();

        UploadedAttachmentDto signatureWithoutWatermark = mediaService.uploadSignature(
                signatureFile, latitude, longitude, now, email);

        List<UploadedAttachmentDto> proofDtos = new java.util.ArrayList<>();
        if (proofFiles != null) {
            for (MultipartFile proof : proofFiles) {
                if (!proof.isEmpty()) {
                    proofDtos.add(mediaService.uploadMedia(proof, latitude, longitude, now, email));
                }
            }
        }

        return ResponseEntity.ok(service.signWorkOrder(id, signatureWithoutWatermark, proofDtos, email));
    }
}
