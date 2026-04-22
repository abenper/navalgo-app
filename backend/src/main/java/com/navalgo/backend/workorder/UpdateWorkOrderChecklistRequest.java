package com.navalgo.backend.workorder;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotEmpty;

import java.util.List;

public record UpdateWorkOrderChecklistRequest(
        @NotEmpty @Valid List<WorkOrderChecklistItemUpdateRequest> items
) {
}