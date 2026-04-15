package com.navalgo.backend.leave;

import java.time.LocalDate;
import java.time.temporal.ChronoUnit;

public record LeaveRequestDto(
        Long id,
        Long workerId,
        String workerName,
        String reason,
        LocalDate startDate,
        LocalDate endDate,
        long requestedDays,
        LeaveStatus status
) {
    public static LeaveRequestDto from(LeaveRequestEntity entity) {
        return new LeaveRequestDto(
                entity.getId(),
                entity.getWorker().getId(),
                entity.getWorker().getFullName(),
                entity.getReason(),
                entity.getStartDate(),
                entity.getEndDate(),
                ChronoUnit.DAYS.between(entity.getStartDate(), entity.getEndDate()) + 1,
                entity.getStatus()
        );
    }
}
