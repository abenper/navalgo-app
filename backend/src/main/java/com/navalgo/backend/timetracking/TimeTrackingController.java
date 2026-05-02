package com.navalgo.backend.timetracking;

import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;
import com.navalgo.backend.worker.CurrentUserWorkerResolver;

import java.util.List;

@RestController
@RequestMapping("/api/time-entries")
public class TimeTrackingController {

    private final TimeTrackingService service;
    private final CurrentUserWorkerResolver currentUserWorkerResolver;

    public TimeTrackingController(TimeTrackingService service,
                                  CurrentUserWorkerResolver currentUserWorkerResolver) {
        this.service = service;
        this.currentUserWorkerResolver = currentUserWorkerResolver;
    }

    @PostMapping("/clock-in")
    @PreAuthorize("hasAnyRole('ADMIN','WORKER')")
    public ResponseEntity<TimeEntryDto> clockIn(@RequestBody @Valid ClockRequest request,
                                                Authentication authentication) {
        validateWorkerScope(request.workerId(), authentication);
        return ResponseEntity.ok(service.clockIn(
                request.workerId(),
                request.workSite(),
                request.plannedClockOut(),
                request.latitude(),
                request.longitude()
        ));
    }

    @PostMapping("/clock-out")
    @PreAuthorize("hasAnyRole('ADMIN','WORKER')")
    public ResponseEntity<TimeEntryDto> clockOut(@RequestBody @Valid ClockRequest request,
                                                 Authentication authentication) {
        validateWorkerScope(request.workerId(), authentication);
        return ResponseEntity.ok(service.clockOut(request.workerId()));
    }

    @GetMapping("/worker/{workerId}")
    @PreAuthorize("hasAnyRole('ADMIN','WORKER')")
    public ResponseEntity<List<TimeEntryDto>> byWorker(@PathVariable Long workerId,
                                                       Authentication authentication) {
        validateWorkerScope(workerId, authentication);
        return ResponseEntity.ok(service.listByWorker(workerId));
    }

    @GetMapping("/today-summary")
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<TodayClockedWorkersSummaryDto> todaySummary() {
        return ResponseEntity.ok(service.getTodaySummary());
    }

    @GetMapping("/admin/worker-stats")
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<List<WorkerTimeTrackingStatsDto>> workerStats() {
        return ResponseEntity.ok(service.getWorkerStats());
    }

    @GetMapping("/admin/workers/{workerId}/insight")
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<WorkerTimeTrackingInsightDto> workerInsight(@PathVariable Long workerId) {
        return ResponseEntity.ok(service.getWorkerInsight(workerId));
    }

    @PatchMapping("/{entryId}")
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<TimeEntryDto> updateEntry(@PathVariable Long entryId,
                                                    @RequestBody @Valid UpdateTimeEntryRequest request) {
        return ResponseEntity.ok(service.updateEntry(entryId, request));
    }

    private void validateWorkerScope(Long targetWorkerId, Authentication authentication) {
        boolean isAdmin = authentication.getAuthorities().stream()
                .anyMatch(a -> "ROLE_ADMIN".equals(a.getAuthority()));

        if (isAdmin) {
            return;
        }

        Long currentWorkerId = currentUserWorkerResolver.findWorkerIdByEmail(authentication.getName());
        if (!currentWorkerId.equals(targetWorkerId)) {
            throw new AccessDeniedException("Solo puedes operar sobre tus propios fichajes");
        }
    }
}
