package com.navalgo.backend.fleet;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

import java.util.List;

public record UpdateVesselRequest(
        @NotBlank @Size(max = 255) String name,
        @NotBlank @Size(max = 255) String registrationNumber,
        @Size(max = 255) String model,
        Integer engineCount,
        List<String> engineLabels,
        Double lengthMeters,
        @NotNull Long ownerId
) {
}
