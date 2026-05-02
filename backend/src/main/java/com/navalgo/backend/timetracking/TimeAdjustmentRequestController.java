package com.navalgo.backend.timetracking;

import com.navalgo.backend.worker.CurrentUserWorkerResolver;
import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;

@RestController
@RequestMapping("/api/time-adjustments")
public class TimeAdjustmentRequestController {

    private final CurrentUserWorkerResolver currentUserWorkerResolver;
    private final TimeAdjustmentRequestService timeAdjustmentRequestService;

    public TimeAdjustmentRequestController(CurrentUserWorkerResolver currentUserWorkerResolver,
                                           TimeAdjustmentRequestService timeAdjustmentRequestService) {
        this.currentUserWorkerResolver = currentUserWorkerResolver;
        this.timeAdjustmentRequestService = timeAdjustmentRequestService;
    }

    @GetMapping
    @PreAuthorize("hasAnyRole('ADMIN','WORKER')")
    public ResponseEntity<List<TimeAdjustmentRequestDto>> list(Authentication authentication,
                                                               @RequestParam(required = false) TimeAdjustmentRequestStatus status) {
        boolean isAdmin = authentication.getAuthorities().stream()
                .anyMatch(authority -> "ROLE_ADMIN".equals(authority.getAuthority()));
        Long currentWorkerId = currentUserWorkerResolver.findWorkerIdByEmail(authentication.getName());
        return ResponseEntity.ok(timeAdjustmentRequestService.listForUser(currentWorkerId, isAdmin, status));
    }

    @PostMapping
    @PreAuthorize("hasAnyRole('ADMIN','WORKER')")
    public ResponseEntity<TimeAdjustmentRequestDto> create(Authentication authentication,
                                                           @Valid @RequestBody CreateTimeAdjustmentRequest request) {
        Long currentWorkerId = currentUserWorkerResolver.findWorkerIdByEmail(authentication.getName());
        return ResponseEntity.ok(timeAdjustmentRequestService.create(currentWorkerId, request));
    }

    @PatchMapping("/{id}")
    @PreAuthorize("hasAnyRole('ADMIN','WORKER')")
    public ResponseEntity<TimeAdjustmentRequestDto> update(@PathVariable Long id,
                                                           Authentication authentication,
                                                           @Valid @RequestBody CreateTimeAdjustmentRequest request) {
        Long currentWorkerId = currentUserWorkerResolver.findWorkerIdByEmail(authentication.getName());
        return ResponseEntity.ok(timeAdjustmentRequestService.update(id, currentWorkerId, request));
    }

    @PatchMapping("/{id}/status")
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<TimeAdjustmentRequestDto> review(@PathVariable Long id,
                                                           Authentication authentication,
                                                           @Valid @RequestBody ReviewTimeAdjustmentRequest request) {
        return ResponseEntity.ok(timeAdjustmentRequestService.review(id, request, authentication.getName()));
    }

    @DeleteMapping("/{id}")
    @PreAuthorize("hasAnyRole('ADMIN','WORKER')")
    public ResponseEntity<Void> delete(@PathVariable Long id,
                                       Authentication authentication) {
        boolean isAdmin = authentication.getAuthorities().stream()
                .anyMatch(authority -> "ROLE_ADMIN".equals(authority.getAuthority()));
        Long currentWorkerId = currentUserWorkerResolver.findWorkerIdByEmail(authentication.getName());
        timeAdjustmentRequestService.delete(id, currentWorkerId, isAdmin);
        return ResponseEntity.noContent().build();
    }
}
