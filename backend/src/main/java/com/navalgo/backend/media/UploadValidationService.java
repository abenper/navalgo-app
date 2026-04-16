package com.navalgo.backend.media;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

import java.util.Locale;
import java.util.Set;

@Service
public class UploadValidationService {

    private static final Set<String> ALLOWED_IMAGE_TYPES = Set.of(
            "image/jpeg",
            "image/png",
            "image/webp"
    );
    private static final Set<String> ALLOWED_VIDEO_TYPES = Set.of(
            "video/mp4",
            "video/quicktime",
            "video/x-msvideo",
            "video/webm"
    );

    private final long maxImageBytes;
    private final long maxVideoBytes;
    private final long maxSignatureBytes;
    private final long maxProfilePhotoBytes;

    public UploadValidationService(
            @Value("${app.media.max-image-size-bytes:10485760}") long maxImageBytes,
            @Value("${app.media.max-video-size-bytes:26214400}") long maxVideoBytes,
            @Value("${app.media.max-signature-size-bytes:5242880}") long maxSignatureBytes,
            @Value("${app.media.max-profile-photo-size-bytes:5242880}") long maxProfilePhotoBytes
    ) {
        this.maxImageBytes = maxImageBytes;
        this.maxVideoBytes = maxVideoBytes;
        this.maxSignatureBytes = maxSignatureBytes;
        this.maxProfilePhotoBytes = maxProfilePhotoBytes;
    }

    public void validateWorkOrderAttachment(MultipartFile file, boolean allowVideo) {
        validateCommon(file);
        String contentType = normalizeContentType(file);
        if (ALLOWED_IMAGE_TYPES.contains(contentType)) {
            validateMaxSize(file, maxImageBytes, "La imagen supera el tamano maximo permitido de 10MB");
            return;
        }
        if (allowVideo && ALLOWED_VIDEO_TYPES.contains(contentType)) {
            validateMaxSize(file, maxVideoBytes, "El video supera el tamano maximo permitido de 100MB");
            return;
        }
        throw new IllegalArgumentException("Tipo de archivo no permitido");
    }

    public void validateSignature(MultipartFile file) {
        validateCommon(file);
        String contentType = normalizeContentType(file);
        if (!ALLOWED_IMAGE_TYPES.contains(contentType)) {
            throw new IllegalArgumentException("La firma debe ser una imagen valida");
        }
        validateMaxSize(file, maxSignatureBytes, "La firma supera el tamano maximo permitido de 5MB");
    }

    public void validateProfilePhoto(MultipartFile file) {
        validateCommon(file);
        String contentType = normalizeContentType(file);
        if (!ALLOWED_IMAGE_TYPES.contains(contentType)) {
            throw new IllegalArgumentException("La foto de perfil debe ser una imagen valida");
        }
        validateMaxSize(file, maxProfilePhotoBytes, "La foto de perfil supera el tamano maximo permitido de 5MB");
    }

    private void validateCommon(MultipartFile file) {
        if (file == null || file.isEmpty()) {
            throw new IllegalArgumentException("El archivo es obligatorio");
        }
        String originalName = file.getOriginalFilename();
        if (originalName != null && originalName.length() > 255) {
            throw new IllegalArgumentException("El nombre del archivo es demasiado largo");
        }
    }

    private void validateMaxSize(MultipartFile file, long maxBytes, String message) {
        if (file.getSize() > maxBytes) {
            throw new IllegalArgumentException(message);
        }
    }

    private String normalizeContentType(MultipartFile file) {
        return file.getContentType() == null
                ? ""
                : file.getContentType().trim().toLowerCase(Locale.ROOT);
    }
}