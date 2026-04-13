package com.navalgo.backend.worker;

import com.navalgo.backend.common.Role;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

public record CreateWorkerRequest(
        @NotBlank String fullName,
        @NotBlank @Email String email,
        String password,
        String speciality,
        @NotNull Role role,
        boolean canEditWorkOrders
) {
}
