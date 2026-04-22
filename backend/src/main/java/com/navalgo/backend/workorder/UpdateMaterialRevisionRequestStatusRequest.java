package com.navalgo.backend.workorder;

import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

public record UpdateMaterialRevisionRequestStatusRequest(
        @NotNull MaterialRevisionRequestStatus status,
        @Size(max = 1000) String resolutionNote
) {
}