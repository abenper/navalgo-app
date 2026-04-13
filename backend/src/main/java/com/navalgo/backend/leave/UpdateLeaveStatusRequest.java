package com.navalgo.backend.leave;

import jakarta.validation.constraints.NotNull;

public record UpdateLeaveStatusRequest(@NotNull LeaveStatus status) {
}
