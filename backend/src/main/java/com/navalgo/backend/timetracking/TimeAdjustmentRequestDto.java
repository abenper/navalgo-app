package com.navalgo.backend.timetracking;

import java.time.Instant;
import java.time.LocalDate;

public record TimeAdjustmentRequestDto(
        Long id,
        Long workerId,
        String workerName,
        Long timeEntryId,
        LocalDate workDate,
        Instant requestedClockIn,
        Instant requestedClockOut,
        TimeEntryWorkSite workSite,
        String reason,
        TimeAdjustmentRequestStatus status,
        String adminComment,
        Instant createdAt,
        Instant reviewedAt,
        Long reviewedByWorkerId,
        String reviewedByWorkerName
) {
    public static TimeAdjustmentRequestDto from(TimeAdjustmentRequest entity) {
        return new TimeAdjustmentRequestDto(
                entity.getId(),
                entity.getWorker().getId(),
                entity.getWorker().getFullName(),
                entity.getTimeEntry() != null ? entity.getTimeEntry().getId() : null,
                entity.getWorkDate(),
                entity.getRequestedClockIn(),
                entity.getRequestedClockOut(),
                entity.getWorkSite(),
                entity.getReason(),
                entity.getStatus(),
                entity.getAdminComment(),
                entity.getCreatedAt(),
                entity.getReviewedAt(),
                entity.getReviewedByWorker() != null ? entity.getReviewedByWorker().getId() : null,
                entity.getReviewedByWorker() != null ? entity.getReviewedByWorker().getFullName() : null
        );
    }
}