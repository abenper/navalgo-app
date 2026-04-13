package com.navalgo.backend.fleet;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

public record CreateVesselRequest(
        @NotBlank String name,
        @NotBlank String registrationNumber,
        String model,
        Integer engineCount,
        Double lengthMeters,
        @NotNull Long ownerId
) {
}
