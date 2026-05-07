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
        boolean registrationCompleted,
        boolean canEditWorkOrders,
        LocalDate contractStartDate,
        String photoUrl
) {
    public static WorkerDto from(Worker worker, boolean registrationCompleted) {
        return new WorkerDto(
                worker.getId(),
                worker.getFullName(),
                worker.getEmail(),
                worker.getSpeciality(),
                worker.getRole(),
                worker.isActive(),
                worker.isMustChangePassword(),
                registrationCompleted,
                worker.isCanEditWorkOrders(),
                worker.getContractStartDate(),
                worker.getPhotoUrl()
        );
    }
}
