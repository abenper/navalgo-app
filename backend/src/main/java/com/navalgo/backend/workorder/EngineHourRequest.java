package com.navalgo.backend.workorder;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.PositiveOrZero;
import jakarta.validation.constraints.NotNull;

public record EngineHourRequest(
        @NotBlank String engineLabel,
        @NotNull @PositiveOrZero Integer hours
) {
}
