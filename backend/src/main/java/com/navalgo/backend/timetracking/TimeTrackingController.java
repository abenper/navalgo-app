package com.navalgo.backend.timetracking;

import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/time-entries")
public class TimeTrackingController {

    private final TimeTrackingService service;

    public TimeTrackingController(TimeTrackingService service) {
        this.service = service;
    }

    @PostMapping("/clock-in")
    @PreAuthorize("hasAnyRole('ADMIN','WORKER')")
    public ResponseEntity<TimeEntryDto> clockIn(@RequestBody @Valid ClockRequest request) {
        return ResponseEntity.ok(service.clockIn(request.workerId()));
    }

    @PostMapping("/clock-out")
    @PreAuthorize("hasAnyRole('ADMIN','WORKER')")
    public ResponseEntity<TimeEntryDto> clockOut(@RequestBody @Valid ClockRequest request) {
        return ResponseEntity.ok(service.clockOut(request.workerId()));
    }

    @GetMapping("/worker/{workerId}")
    @PreAuthorize("hasAnyRole('ADMIN','WORKER')")
    public ResponseEntity<List<TimeEntryDto>> byWorker(@PathVariable Long workerId) {
        return ResponseEntity.ok(service.listByWorker(workerId));
    }
}
