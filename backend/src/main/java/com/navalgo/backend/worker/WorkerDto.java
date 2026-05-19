package com.navalgo.backend.worker;

import com.navalgo.backend.common.Role;

import java.time.LocalDate;

public record WorkerDto(
        Long id,
        String fullName,
        String email,
        String speciality,
        String phonePrefix,
        String phone,
        Role role,
        boolean active,
        boolean mustChangePassword,
        boolean registrationCompleted,
        boolean canEditWorkOrders,
        boolean emailVerified,
        Long ownerId,
        LocalDate contractStartDate,
        String photoUrl
) {
    public static WorkerDto from(Worker worker, boolean registrationCompleted) {
        return new WorkerDto(
                worker.getId(),
                worker.getFullName(),
                worker.getEmail(),
                worker.getSpeciality(),
                worker.getPhonePrefix(),
                worker.getPhone(),
                worker.getRole(),
                worker.isActive(),
                worker.isMustChangePassword(),
                registrationCompleted,
                worker.isCanEditWorkOrders(),
                worker.isEmailVerified(),
                worker.getOwner() != null ? worker.getOwner().getId() : null,
                worker.getContractStartDate(),
                worker.getPhotoUrl()
        );
    }
}
