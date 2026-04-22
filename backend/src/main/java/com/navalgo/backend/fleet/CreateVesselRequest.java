package com.navalgo.backend.fleet;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

import java.util.List;

public record CreateVesselRequest(
        @NotBlank @Size(max = 255) String name,
        @NotBlank @Size(max = 255) String registrationNumber,
        @Size(max = 255) String model,
        Integer engineCount,
        List<String> engineLabels,
        List<@Size(max = 255) String> engineSerialNumbers,
        Double lengthMeters,
        @NotNull Long ownerId
) {
}
