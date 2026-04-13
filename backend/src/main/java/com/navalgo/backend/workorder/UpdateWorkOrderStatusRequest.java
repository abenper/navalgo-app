package com.navalgo.backend.workorder;

import jakarta.validation.constraints.NotNull;

public record UpdateWorkOrderStatusRequest(@NotNull WorkOrderStatus status) {
}
