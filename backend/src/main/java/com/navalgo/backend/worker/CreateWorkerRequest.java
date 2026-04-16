package com.navalgo.backend.worker;

import com.navalgo.backend.common.Role;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

import java.time.LocalDate;

public record CreateWorkerRequest(
        @NotBlank @Size(max = 255) String fullName,
        @NotBlank @Email @Size(max = 255) String email,
        @Size(min = 12, max = 128) String password,
        @Size(max = 255) String speciality,
        @NotNull Role role,
        boolean canEditWorkOrders,
        LocalDate contractStartDate
) {
}
