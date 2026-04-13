package com.navalgo.backend.leave;

import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/leave-requests")
public class LeaveRequestController {

    private final LeaveRequestService service;

    public LeaveRequestController(LeaveRequestService service) {
        this.service = service;
    }

    @GetMapping
    @PreAuthorize("hasAnyRole('ADMIN','WORKER')")
    public ResponseEntity<List<LeaveRequestDto>> list(@RequestParam(required = false) Long workerId) {
        return ResponseEntity.ok(service.list(workerId));
    }

    @PostMapping
    @PreAuthorize("hasAnyRole('ADMIN','WORKER')")
    public ResponseEntity<LeaveRequestDto> create(@RequestBody @Valid CreateLeaveRequest request) {
        return ResponseEntity.ok(service.create(request));
    }

    @PatchMapping("/{id}/status")
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<LeaveRequestDto> updateStatus(@PathVariable Long id,
                                                        @RequestBody @Valid UpdateLeaveStatusRequest request) {
        return ResponseEntity.ok(service.updateStatus(id, request));
    }
}
