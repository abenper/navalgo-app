package com.navalgo.backend.workorder;

import com.navalgo.backend.worker.Worker;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.time.Instant;
import java.time.ZoneOffset;
import java.time.format.DateTimeFormatter;
import java.util.Comparator;
import java.util.Locale;

@Service
public class WorkOrderEvidenceService {

    private static final DateTimeFormatter INSTANT_FORMATTER = DateTimeFormatter.ISO_INSTANT.withZone(ZoneOffset.UTC);
    private final SecretKeySpec secretKeySpec;

    public WorkOrderEvidenceService(@Value("${app.evidence.secret:${app.jwt.secret}}") String secret) {
        if (secret == null || secret.isBlank() || secret.length() < 32) {
            throw new IllegalStateException("APP_EVIDENCE_SECRET or APP_JWT_SECRET must be at least 32 characters long");
        }
        this.secretKeySpec = new SecretKeySpec(secret.getBytes(StandardCharsets.UTF_8), "HmacSHA256");
    }

    public String signAttachment(WorkOrder workOrder, WorkOrderAttachment attachment) {
        return hmacSha256Hex(buildAttachmentPayload(workOrder, attachment));
    }

    public WorkOrderSeal sealWorkOrder(WorkOrder workOrder, Instant sealedAt) {
        String manifestPayload = buildWorkOrderManifestPayload(workOrder, sealedAt);
        String manifestHash = sha256Hex(manifestPayload);
        String serverSignature = hmacSha256Hex(manifestPayload);
        return new WorkOrderSeal(manifestHash, serverSignature);
    }

    private String buildAttachmentPayload(WorkOrder workOrder, WorkOrderAttachment attachment) {
        StringBuilder builder = new StringBuilder();
        append(builder, "workOrderId", workOrder.getId());
        append(builder, "attachmentId", attachment.getId());
        append(builder, "fileUrl", attachment.getFileUrl());
        append(builder, "storageObjectKey", attachment.getStorageObjectKey());
        append(builder, "fileType", attachment.getFileType());
        append(builder, "contentType", attachment.getContentType());
        append(builder, "originalFileName", attachment.getOriginalFileName());
        append(builder, "sha256Hex", attachment.getSha256Hex());
        append(builder, "fileSizeBytes", attachment.getFileSizeBytes());
        append(builder, "capturedAt", attachment.getCapturedAt());
        append(builder, "uploadedAt", attachment.getUploadedAt());
        append(builder, "latitude", attachment.getLatitude());
        append(builder, "longitude", attachment.getLongitude());
        append(builder, "watermarked", attachment.isWatermarked());
        append(builder, "audioRemoved", attachment.isAudioRemoved());
        append(builder, "uploadIp", attachment.getUploadIp());
        append(builder, "uploadUserAgent", attachment.getUploadUserAgent());
        Worker uploader = attachment.getUploadedByWorker();
        append(builder, "uploadedByWorkerId", uploader != null ? uploader.getId() : null);
        append(builder, "uploadedByWorkerEmail", uploader != null ? uploader.getEmail() : null);
        return builder.toString();
    }

    private String buildWorkOrderManifestPayload(WorkOrder workOrder, Instant sealedAt) {
        StringBuilder builder = new StringBuilder();
        append(builder, "workOrderId", workOrder.getId());
        append(builder, "title", workOrder.getTitle());
        append(builder, "description", workOrder.getDescription());
        append(builder, "status", workOrder.getStatus());
        append(builder, "priority", workOrder.getPriority());
        append(builder, "ownerId", workOrder.getOwner() != null ? workOrder.getOwner().getId() : null);
        append(builder, "vesselId", workOrder.getVessel() != null ? workOrder.getVessel().getId() : null);
        append(builder, "createdAt", workOrder.getCreatedAt());
        append(builder, "signedAt", workOrder.getSignedAt());
        append(builder, "clientSignedAt", workOrder.getClientSignedAt());
        append(builder, "signatureUrl", workOrder.getSignatureUrl());
        append(builder, "clientSignatureUrl", workOrder.getClientSignatureUrl());
        append(builder, "sealedAt", sealedAt);
        workOrder.getAttachments().stream()
                .sorted(Comparator
                        .comparing(WorkOrderAttachment::getUploadedAt, Comparator.nullsLast(Comparator.naturalOrder()))
                        .thenComparing(WorkOrderAttachment::getId, Comparator.nullsLast(Comparator.naturalOrder()))
                        .thenComparing(WorkOrderAttachment::getFileUrl, Comparator.nullsLast(String::compareTo)))
                .forEach(attachment -> {
                    builder.append("attachment{");
                    builder.append(buildAttachmentPayload(workOrder, attachment));
                    builder.append("}\n");
                });
        return builder.toString();
    }

    private void append(StringBuilder builder, String key, Object value) {
        builder.append(key)
                .append('=')
                .append(normalizeValue(value))
                .append('\n');
    }

    private String normalizeValue(Object value) {
        if (value == null) {
            return "";
        }
        if (value instanceof Instant instant) {
            return INSTANT_FORMATTER.format(instant);
        }
        return value.toString().trim();
    }

    private String sha256Hex(String value) {
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            byte[] hash = digest.digest(value.getBytes(StandardCharsets.UTF_8));
            return bytesToHex(hash);
        } catch (NoSuchAlgorithmException exception) {
            throw new IllegalStateException("SHA-256 no disponible", exception);
        }
    }

    private String hmacSha256Hex(String value) {
        try {
            Mac mac = Mac.getInstance("HmacSHA256");
            mac.init(secretKeySpec);
            return bytesToHex(mac.doFinal(value.getBytes(StandardCharsets.UTF_8)));
        } catch (Exception exception) {
            throw new IllegalStateException("No se pudo firmar la evidencia", exception);
        }
    }

    private String bytesToHex(byte[] bytes) {
        StringBuilder builder = new StringBuilder(bytes.length * 2);
        for (byte value : bytes) {
            builder.append(String.format(Locale.ROOT, "%02x", value));
        }
        return builder.toString();
    }

    public record WorkOrderSeal(
            String manifestHash,
            String serverSignature
    ) {
    }
}
