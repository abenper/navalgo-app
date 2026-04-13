package com.navalgo.backend.timetracking;

import jakarta.validation.constraints.NotNull;

public record ClockRequest(@NotNull Long workerId) {
}
