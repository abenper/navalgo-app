package com.navalgo.backend.workorder;

import java.time.Instant;

public record MaterialRevisionRequestDto(
        Long id,
        Long checklistItemSnapshotId,
        Long sourceTemplateId,
        Long sourceTemplateItemId,
        String articleName,
        String reference,
        String observations,
        MaterialRevisionRequestStatus status,
        Long requestedByWorkerId,
        String requestedByWorkerName,
        Instant createdAt,
        Long reviewedByWorkerId,
        String reviewedByWorkerName,
        Instant reviewedAt,
        String resolutionNote
) {
}