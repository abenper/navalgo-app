package com.navalgo.backend.budget;

import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

import java.math.BigDecimal;

public record CreateBudgetRequest(
        @NotNull Long ownerId,
        @NotNull Long vesselId,
        @Size(max = 255) String contactEmail,
        @NotBlank @Size(max = 255) String title,
        @Size(max = 3000) String description,
        @DecimalMin(value = "0.0", inclusive = true) BigDecimal amount,
        @Size(max = 3) String currency,
        @NotBlank @Size(max = 2000) String pdfUrl
) {
}
