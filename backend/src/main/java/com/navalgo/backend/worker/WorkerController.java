package com.navalgo.backend.worker;

import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;
import com.navalgo.backend.workorder.WorkOrderMediaService;
import com.navalgo.backend.workorder.UploadedAttachmentDto;

import java.util.List;

@RestController
@RequestMapping("/api/workers")
public class WorkerController {

    private final WorkerService workerService;
    private final WorkOrderMediaService mediaService;

    public WorkerController(WorkerService workerService, WorkOrderMediaService mediaService) {
        this.workerService = workerService;
        this.mediaService = mediaService;
    }

    @GetMapping
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<List<WorkerDto>> list() {
        return ResponseEntity.ok(workerService.findAll());
    }

    @PostMapping
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<CreateWorkerResponse> create(@RequestBody @Valid CreateWorkerRequest request) {
        return ResponseEntity.ok(workerService.create(request));
    }

    @PutMapping("/{id}")
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<WorkerDto> update(@PathVariable Long id,
                                            @RequestBody @Valid UpdateWorkerRequest request) {
        return ResponseEntity.ok(workerService.update(id, request));
    }

    @DeleteMapping("/{id}")
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<Void> delete(@PathVariable Long id) {
        workerService.delete(id);
        return ResponseEntity.noContent().build();
    }

    @PatchMapping("/{id}/active")
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<WorkerDto> updateStatus(@PathVariable Long id,
                                                  @RequestBody UpdateWorkerStatusRequest request) {
        return ResponseEntity.ok(workerService.setActive(id, request.active()));
    }

    @PatchMapping("/{id}/reset-password")
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<ResetWorkerPasswordResponse> resetPassword(@PathVariable Long id) {
        return ResponseEntity.ok(workerService.resetPassword(id));
    }

    @PatchMapping("/{id}/permissions/work-orders")
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<WorkerDto> updateWorkOrderPermission(@PathVariable Long id,
                                                               @RequestBody UpdateWorkOrderEditPermissionRequest request) {
        return ResponseEntity.ok(workerService.setWorkOrderEditPermission(id, request.canEditWorkOrders()));
    }

    @PostMapping(value = "/{id}/photo", consumes = "multipart/form-data")
    @PreAuthorize("hasAnyRole('ADMIN','WORKER')")
    public ResponseEntity<WorkerDto> uploadPhoto(@PathVariable Long id,
                                                 @RequestParam("file") MultipartFile file,
                                                 Authentication authentication) {
        boolean isAdmin = authentication.getAuthorities().stream()
                .anyMatch(a -> "ROLE_ADMIN".equals(a.getAuthority()));
        String email = authentication.getName();
        UploadedAttachmentDto uploaded = mediaService.uploadProfilePhoto(file, email);
        WorkerDto updated = workerService.updatePhoto(id, uploaded.fileUrl(), isAdmin, email);
        return ResponseEntity.ok(updated);
    }
}
