package com.navalgo.backend.budget;

import jakarta.validation.constraints.DecimalMin;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

import java.math.BigDecimal;

public record UpdateBudgetDraftRequest(
        Long ownerId,
        @Size(max = 255) String contactEmail,
        @Size(max = 255) String newClientName,
        @NotBlank @Size(max = 255) String title,
        @Size(max = 3000) String description,
        @DecimalMin(value = "0.0", inclusive = true) BigDecimal amount,
        @Size(max = 3) String currency,
        @NotBlank @Size(max = 2000) String pdfUrl
) {
}
