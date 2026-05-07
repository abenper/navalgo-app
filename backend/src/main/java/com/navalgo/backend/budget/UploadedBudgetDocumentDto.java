package com.navalgo.backend.budget;

public record UploadedBudgetDocumentDto(
        String fileUrl,
        String originalFileName
) {
}
