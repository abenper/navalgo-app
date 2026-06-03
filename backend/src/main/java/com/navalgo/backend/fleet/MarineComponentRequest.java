package com.navalgo.backend.fleet;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

import java.util.List;

public record MarineComponentRequest(
        @NotNull VesselComponentType type,
        @NotBlank String name,
        String manufacturer,
        String model,
        List<Long> templateIds
) {}
