package com.navalgo.backend.budget;

import com.navalgo.backend.media.MediaProperties;
import com.navalgo.backend.media.UploadValidationService;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;
import software.amazon.awssdk.core.sync.RequestBody;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.model.PutObjectRequest;

import java.io.IOException;
import java.text.Normalizer;
import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import java.util.Locale;
import java.util.UUID;

@Service
@Transactional(readOnly = true)
public class BudgetMediaService {

    private static final DateTimeFormatter DATE_FORMATTER = DateTimeFormatter.ISO_LOCAL_DATE;

    private final S3Client s3Client;
    private final MediaProperties mediaProperties;
    private final UploadValidationService uploadValidationService;

    public BudgetMediaService(S3Client s3Client,
                              MediaProperties mediaProperties,
                              UploadValidationService uploadValidationService) {
        this.s3Client = s3Client;
        this.mediaProperties = mediaProperties;
        this.uploadValidationService = uploadValidationService;
    }

    public UploadedBudgetDocumentDto uploadBudgetPdf(MultipartFile file,
                                                     String ownerName,
                                                     String vesselName) {
        uploadValidationService.validateBudgetPdf(file);
        String key = buildObjectKey(ownerName, vesselName);
        try {
            uploadToSpaces(key, file.getBytes(), "application/pdf");
        } catch (IOException exception) {
            throw new IllegalStateException("No se pudo procesar el PDF del presupuesto", exception);
        }
        return new UploadedBudgetDocumentDto(buildPublicUrl(key), file.getOriginalFilename());
    }

    private void uploadToSpaces(String key, byte[] bytes, String contentType) {
        PutObjectRequest request = PutObjectRequest.builder()
                .bucket(mediaProperties.spacesBucket())
                .key(key)
                .contentType(contentType)
                .build();
        try {
            s3Client.putObject(request, RequestBody.fromBytes(bytes));
        } catch (RuntimeException exception) {
            throw new IllegalStateException("No se pudo subir el PDF al almacenamiento", exception);
        }
    }

    private String buildObjectKey(String ownerName, String vesselName) {
        String ownerFolder = sanitizeSegment(ownerName == null ? "sin-cliente" : ownerName);
        String vesselFolder = sanitizeSegment(vesselName == null ? "sin-embarcacion" : vesselName);
        return "presupuestos/" + ownerFolder + "/" + vesselFolder + "/" + DATE_FORMATTER.format(LocalDate.now())
                + "/" + UUID.randomUUID() + ".pdf";
    }

    private String sanitizeSegment(String raw) {
        if (raw == null || raw.isBlank()) {
            return "na";
        }

        String normalized = Normalizer.normalize(raw.trim().toLowerCase(Locale.ROOT), Normalizer.Form.NFD)
                .replaceAll("\\p{M}+", "");
        String safe = normalized
                .replaceAll("[^a-z0-9._-]+", "-")
                .replaceAll("-+", "-")
                .replaceAll("^-|-$", "");
        return safe.isBlank() ? "na" : safe;
    }

    private String buildPublicUrl(String key) {
        String base = mediaProperties.publicBaseUrl();
        if (base.endsWith("/")) {
            return base + key;
        }
        return base + "/" + key;
    }
}
