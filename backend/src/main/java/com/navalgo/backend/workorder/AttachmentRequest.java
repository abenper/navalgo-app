package com.navalgo.backend.workorder;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

import java.time.Instant;

public record AttachmentRequest(
        @NotBlank @Size(max = 2000) String fileUrl,
        @NotBlank @Size(max = 255) String fileType,
        @Size(max = 255) String originalFileName,
        Instant capturedAt,
        Double latitude,
        Double longitude,
        boolean watermarked,
        boolean audioRemoved
) {
}
