package com.navalgo.backend.worker;

import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/workers")
public class WorkerController {

    private final WorkerService workerService;

    public WorkerController(WorkerService workerService) {
        this.workerService = workerService;
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
}
