package com.navalgo.backend.workorder;

import java.time.Instant;

public record AttachmentInfoDto(
    Long id,
        String fileUrl,
        String fileType,
        String originalFileName,
        Instant capturedAt,
        Double latitude,
        Double longitude,
        boolean watermarked,
        boolean audioRemoved
) {
    public static AttachmentInfoDto from(WorkOrderAttachment attachment) {
        return new AttachmentInfoDto(
                attachment.getId(),
                attachment.getFileUrl(),
                attachment.getFileType(),
                attachment.getOriginalFileName(),
                attachment.getCapturedAt(),
                attachment.getLatitude(),
                attachment.getLongitude(),
                attachment.isWatermarked(),
                attachment.isAudioRemoved()
        );
    }
}
