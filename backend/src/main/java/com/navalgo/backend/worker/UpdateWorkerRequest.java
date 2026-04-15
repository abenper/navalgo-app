package com.navalgo.backend.worker;

import com.navalgo.backend.common.Role;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

import java.time.LocalDate;

public record UpdateWorkerRequest(
        @NotBlank String fullName,
        @NotBlank @Email String email,
        String speciality,
        @NotNull Role role,
        boolean canEditWorkOrders,
        @NotNull LocalDate contractStartDate
) {
}
