package com.navalgo.backend.workorder;

import java.time.Instant;

public record UploadedAttachmentDto(
        String fileUrl,
        String fileType,
        String originalFileName,
        Instant capturedAt,
        Double latitude,
        Double longitude,
        boolean watermarked,
        boolean audioRemoved
) {
}
