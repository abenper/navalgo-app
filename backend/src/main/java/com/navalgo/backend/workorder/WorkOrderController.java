package com.navalgo.backend.workorder;

import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/work-orders")
public class WorkOrderController {

    private final WorkOrderService service;

    public WorkOrderController(WorkOrderService service) {
        this.service = service;
    }

    @GetMapping
    @PreAuthorize("hasAnyRole('ADMIN','WORKER')")
    public ResponseEntity<List<WorkOrderDto>> list(@RequestParam(required = false) Long workerId) {
        if (workerId != null) {
            return ResponseEntity.ok(service.findByWorker(workerId));
        }
        return ResponseEntity.ok(service.findAll());
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
        return ResponseEntity.ok(service.updateStatus(id, request));
    }
}
