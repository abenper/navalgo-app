package com.navalgo.backend.leave;

import com.navalgo.backend.worker.CurrentUserWorkerResolver;
import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/leave-requests")
public class LeaveRequestController {

    private final LeaveRequestService service;
    private final CurrentUserWorkerResolver currentUserWorkerResolver;

    public LeaveRequestController(LeaveRequestService service,
                                  CurrentUserWorkerResolver currentUserWorkerResolver) {
        this.service = service;
        this.currentUserWorkerResolver = currentUserWorkerResolver;
    }

    @GetMapping
    @PreAuthorize("hasAnyRole('ADMIN','WORKER')")
    public ResponseEntity<List<LeaveRequestDto>> list(@RequestParam(required = false) Long workerId,
                                                      Authentication authentication) {
        Long scopedWorkerId = resolveScopedWorkerId(workerId, authentication);
        return ResponseEntity.ok(service.list(scopedWorkerId));
    }

    @GetMapping("/balance")
    @PreAuthorize("hasAnyRole('ADMIN','WORKER')")
    public ResponseEntity<LeaveBalanceDto> balance(@RequestParam(required = false) Long workerId,
                                                   Authentication authentication) {
        Long scopedWorkerId = resolveScopedWorkerId(workerId, authentication);
        return ResponseEntity.ok(service.getBalance(scopedWorkerId));
    }

    @PostMapping
    @PreAuthorize("hasAnyRole('ADMIN','WORKER')")
    public ResponseEntity<LeaveRequestDto> create(@RequestBody @Valid CreateLeaveRequest request,
                                                  Authentication authentication) {
        boolean isAdmin = authentication.getAuthorities().stream()
                .anyMatch(a -> "ROLE_ADMIN".equals(a.getAuthority()));

        if (!isAdmin) {
            Long currentWorkerId = currentUserWorkerResolver.findWorkerIdByEmail(authentication.getName());
            if (!currentWorkerId.equals(request.workerId())) {
                throw new AccessDeniedException("Solo puedes crear tus propias solicitudes");
            }
        }

        return ResponseEntity.ok(service.create(request));
    }

    @PatchMapping("/{id}/status")
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<LeaveRequestDto> updateStatus(@PathVariable Long id,
                                                        @RequestBody @Valid UpdateLeaveStatusRequest request) {
        return ResponseEntity.ok(service.updateStatus(id, request));
    }

    @PatchMapping("/{id}")
    @PreAuthorize("hasAnyRole('ADMIN','WORKER')")
    public ResponseEntity<LeaveRequestDto> updateRequest(@PathVariable Long id,
                                                         @RequestBody @Valid UpdateLeaveRequest request,
                                                         Authentication authentication) {
        boolean isAdmin = authentication.getAuthorities().stream()
                .anyMatch(a -> "ROLE_ADMIN".equals(a.getAuthority()));
        Long currentWorkerId = isAdmin ? null : currentUserWorkerResolver.findWorkerIdByEmail(authentication.getName());
        return ResponseEntity.ok(service.updateRequest(id, request, currentWorkerId, isAdmin));
    }

    @PatchMapping("/{id}/cancel")
    @PreAuthorize("hasAnyRole('ADMIN','WORKER')")
    public ResponseEntity<LeaveRequestDto> cancelRequest(@PathVariable Long id,
                                                         Authentication authentication) {
        boolean isAdmin = authentication.getAuthorities().stream()
                .anyMatch(a -> "ROLE_ADMIN".equals(a.getAuthority()));
        Long currentWorkerId = isAdmin ? null : currentUserWorkerResolver.findWorkerIdByEmail(authentication.getName());
        return ResponseEntity.ok(service.cancelRequest(id, currentWorkerId, isAdmin));
    }

    @DeleteMapping("/{id}")
    @PreAuthorize("hasAnyRole('ADMIN','WORKER')")
    public ResponseEntity<Void> deleteRequest(@PathVariable Long id,
                                              Authentication authentication) {
        boolean isAdmin = authentication.getAuthorities().stream()
                .anyMatch(a -> "ROLE_ADMIN".equals(a.getAuthority()));
        Long currentWorkerId = isAdmin ? null : currentUserWorkerResolver.findWorkerIdByEmail(authentication.getName());
        service.deleteRequest(id, currentWorkerId, isAdmin);
        return ResponseEntity.noContent().build();
    }

    @PostMapping("/admin-assign")
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<LeaveRequestDto> adminAssign(@RequestBody @Valid AdminAssignLeaveRequest request) {
        return ResponseEntity.ok(service.adminAssign(request));
    }

    private Long resolveScopedWorkerId(Long workerId, Authentication authentication) {
        boolean isAdmin = authentication.getAuthorities().stream()
                .anyMatch(a -> "ROLE_ADMIN".equals(a.getAuthority()));

        if (isAdmin) {
            return workerId;
        }

        Long currentWorkerId = currentUserWorkerResolver.findWorkerIdByEmail(authentication.getName());
        if (workerId != null && !workerId.equals(currentWorkerId)) {
            throw new AccessDeniedException("Solo puedes ver tus propias solicitudes");
        }
        return currentWorkerId;
    }
}
