package com.navalgo.backend.budget;

import java.time.Instant;

public record BudgetEventDto(
        Long id,
        String eventType,
        String actorName,
        String actorRole,
        String note,
        Instant createdAt
) {
}
