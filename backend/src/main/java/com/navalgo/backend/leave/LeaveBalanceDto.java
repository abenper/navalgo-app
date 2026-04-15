package com.navalgo.backend.leave;

public record LeaveBalanceDto(
        Long workerId,
        String workerName,
        double accruedDays,
        long consumedDays,
        double availableDays
) {
}
