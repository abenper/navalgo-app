package com.navalgo.backend.fleet;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

import java.util.List;

public record CreateVesselRequest(
        @NotBlank String name,
        @NotBlank String registrationNumber,
        String model,
        Integer engineCount,
        List<String> engineLabels,
        Double lengthMeters,
        @NotNull Long ownerId
) {
}
