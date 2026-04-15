package com.navalgo.backend.workorder;

import jakarta.validation.constraints.NotBlank;

import java.time.Instant;

public record AttachmentRequest(
        @NotBlank String fileUrl,
        @NotBlank String fileType,
        String originalFileName,
        Instant capturedAt,
        Double latitude,
        Double longitude,
        boolean watermarked,
        boolean audioRemoved
) {
}
