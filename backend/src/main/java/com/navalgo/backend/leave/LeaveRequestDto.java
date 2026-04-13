package com.navalgo.backend.leave;

import java.time.LocalDate;

public record LeaveRequestDto(
        Long id,
        Long workerId,
        String workerName,
        String reason,
        LocalDate startDate,
        LocalDate endDate,
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
                entity.getStatus()
        );
    }
}
