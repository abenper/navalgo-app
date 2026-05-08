package com.navalgo.backend.workorder;

import java.time.Instant;

public record UploadedAttachmentDto(
        String fileUrl,
        String fileType,
        String contentType,
        String originalFileName,
        Instant capturedAt,
        Instant uploadedAt,
        Double latitude,
        Double longitude,
        Long fileSizeBytes,
        String storageObjectKey,
        String sha256Hex,
        boolean watermarked,
        boolean audioRemoved
) {
}
