package com.navalgo.backend.worker;

import com.navalgo.backend.common.Role;

import java.time.LocalDate;

public record WorkerDto(
        Long id,
        String fullName,
        String email,
        String speciality,
        Role role,
    boolean active,
    boolean mustChangePassword,
    boolean canEditWorkOrders,
    LocalDate contractStartDate,
    String photoUrl
) {
    public static WorkerDto from(Worker worker) {
        return new WorkerDto(
                worker.getId(),
                worker.getFullName(),
                worker.getEmail(),
                worker.getSpeciality(),
                worker.getRole(),
                worker.isActive(),
                worker.isMustChangePassword(),
                worker.isCanEditWorkOrders(),
                worker.getContractStartDate(),
                worker.getPhotoUrl()
        );
    }
}
