package com.navalgo.backend.worker;

import com.navalgo.backend.security.JwtService;
import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;
import com.navalgo.backend.workorder.WorkOrderMediaService;
import com.navalgo.backend.workorder.UploadedAttachmentDto;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/workers")
public class WorkerController {

    private final WorkerService workerService;
    private final WorkOrderMediaService mediaService;
    private final JwtService jwtService;

    public WorkerController(WorkerService workerService,
                            WorkOrderMediaService mediaService,
                            JwtService jwtService) {
        this.workerService = workerService;
        this.mediaService = mediaService;
        this.jwtService = jwtService;
    }

    @GetMapping("/me")
    @PreAuthorize("hasAnyRole('ADMIN','COMERCIAL','WORKER')")
    public ResponseEntity<WorkerDto> me(Authentication authentication) {
        return ResponseEntity.ok(workerService.findOwnProfile(authentication.getName()));
    }

    @PutMapping("/me")
    @PreAuthorize("hasAnyRole('ADMIN','COMERCIAL','WORKER')")
    public ResponseEntity<OwnProfileResponse> updateOwnProfile(@RequestBody @Valid UpdateOwnProfileRequest request,
                                                               Authentication authentication) {
        WorkerDto updated = workerService.updateOwnProfile(authentication.getName(), request);
        String token = jwtService.generateToken(updated.email(), Map.of(
                "role", updated.role().name(),
                "userId", updated.id()
        ));
        return ResponseEntity.ok(new OwnProfileResponse(updated, token, jwtService.calculateExpiryInstant()));
    }

    @GetMapping
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<List<WorkerDto>> list() {
        return ResponseEntity.ok(workerService.findAll());
    }

    @PostMapping
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<CreateWorkerResponse> create(@RequestBody @Valid CreateWorkerRequest request,
                                                       Authentication authentication) {
        return ResponseEntity.ok(workerService.create(request, authentication.getName()));
    }

    @PutMapping("/{id}")
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<WorkerDto> update(@PathVariable Long id,
                                            @RequestBody @Valid UpdateWorkerRequest request,
                                            Authentication authentication) {
        return ResponseEntity.ok(workerService.update(id, request, authentication.getName()));
    }

    @DeleteMapping("/{id}")
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<Void> delete(@PathVariable Long id, Authentication authentication) {
        workerService.delete(id, authentication.getName());
        return ResponseEntity.noContent().build();
    }

    @PatchMapping("/{id}/active")
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<WorkerDto> updateStatus(@PathVariable Long id,
                                                  @RequestBody UpdateWorkerStatusRequest request,
                                                  Authentication authentication) {
        return ResponseEntity.ok(workerService.setActive(id, request.active(), authentication.getName()));
    }

    @PatchMapping("/{id}/reset-password")
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<ResetWorkerPasswordResponse> resetPassword(@PathVariable Long id,
                                                                     Authentication authentication) {
        return ResponseEntity.ok(workerService.resetPassword(id, authentication.getName()));
    }

    @PatchMapping("/{id}/permissions/work-orders")
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<WorkerDto> updateWorkOrderPermission(@PathVariable Long id,
                                                               @RequestBody UpdateWorkOrderEditPermissionRequest request,
                                                               Authentication authentication) {
        return ResponseEntity.ok(workerService.setWorkOrderEditPermission(
                id,
                request.canEditWorkOrders(),
                authentication.getName()
        ));
    }

    @PostMapping(value = "/{id}/photo", consumes = "multipart/form-data")
    @PreAuthorize("hasAnyRole('ADMIN','COMERCIAL','WORKER')")
    public ResponseEntity<WorkerDto> uploadPhoto(@PathVariable Long id,
                                                 @RequestParam("file") MultipartFile file,
                                                 Authentication authentication) {
        boolean isAdmin = authentication.getAuthorities().stream()
                .anyMatch(a -> "ROLE_ADMIN".equals(a.getAuthority()));
        String email = authentication.getName();
        String photoOwnerEmail = workerService.resolvePhotoOwnerEmail(id, isAdmin, email);
        UploadedAttachmentDto uploaded = mediaService.uploadProfilePhoto(file, photoOwnerEmail);
        WorkerDto updated = workerService.updatePhoto(id, uploaded.fileUrl(), isAdmin, email);
        return ResponseEntity.ok(updated);
    }
}
