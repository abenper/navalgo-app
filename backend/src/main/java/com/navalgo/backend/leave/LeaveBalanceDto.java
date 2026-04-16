package com.navalgo.backend.leave;

public record LeaveBalanceDto(
        Long workerId,
        String workerName,
        long accruedDays,
        long bonusDays,
        long consumedDays,
        long availableDays
) {
}
