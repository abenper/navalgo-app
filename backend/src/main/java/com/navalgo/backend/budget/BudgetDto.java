package com.navalgo.backend.budget;

import java.math.BigDecimal;
import java.time.Instant;

public record BudgetDto(
        Long id,
        Long ownerId,
        String ownerName,
        String ownerEmail,
        Long vesselId,
        String vesselName,
        Long createdByWorkerId,
        String createdByWorkerName,
        String title,
        String description,
        BigDecimal amount,
        String currency,
        String pdfUrl,
        BudgetStatus status,
        String clientObservations,
        Instant sentAt,
        Instant clientDecidedAt,
        Instant createdAt,
        Instant updatedAt
) {
}
