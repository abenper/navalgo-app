package com.navalgo.backend.workorder;

import java.time.Instant;

public record MaterialTemplateIncidentAlertDto(
        Long requestId,
        String articleName,
        String reference,
        String observations,
        MaterialRevisionRequestStatus status,
        Instant createdAt,
        String requestedByWorkerName
) {
}