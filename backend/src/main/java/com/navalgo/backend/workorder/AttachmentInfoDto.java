package com.navalgo.backend.workorder;

import java.time.Instant;

public record AttachmentInfoDto(
    Long id,
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
        String serverSignature,
        Long uploadedByWorkerId,
        String uploadedByWorkerName,
        String uploadedByWorkerEmail,
        String uploadIp,
        String uploadUserAgent,
        boolean watermarked,
        boolean audioRemoved
) {
    public static AttachmentInfoDto from(WorkOrderAttachment attachment) {
        return new AttachmentInfoDto(
                attachment.getId(),
                attachment.getFileUrl(),
                attachment.getFileType(),
                attachment.getContentType(),
                attachment.getOriginalFileName(),
                attachment.getCapturedAt(),
                attachment.getUploadedAt(),
                attachment.getLatitude(),
                attachment.getLongitude(),
                attachment.getFileSizeBytes(),
                attachment.getStorageObjectKey(),
                attachment.getSha256Hex(),
                attachment.getServerSignature(),
                attachment.getUploadedByWorker() != null ? attachment.getUploadedByWorker().getId() : null,
                attachment.getUploadedByWorker() != null ? attachment.getUploadedByWorker().getFullName() : null,
                attachment.getUploadedByWorker() != null ? attachment.getUploadedByWorker().getEmail() : null,
                attachment.getUploadIp(),
                attachment.getUploadUserAgent(),
                attachment.isWatermarked(),
                attachment.isAudioRemoved()
        );
    }
}
