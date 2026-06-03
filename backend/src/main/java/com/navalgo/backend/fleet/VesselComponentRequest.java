package com.navalgo.backend.fleet;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

import java.util.List;

public record VesselComponentRequest(
        Long componentId,
        @NotNull VesselComponentType type,
        @NotBlank @Size(max = 255) String label,
        @Size(max = 255) String manufacturer,
        @Size(max = 255) String model,
        @Size(max = 255) String serialNumber,
        Integer currentHours,
        List<Long> templateIds
) {
}
