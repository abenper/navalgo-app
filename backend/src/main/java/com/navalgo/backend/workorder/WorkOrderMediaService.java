package com.navalgo.backend.workorder;

import com.navalgo.backend.media.MediaProperties;
import com.navalgo.backend.media.UploadValidationService;
import com.navalgo.backend.worker.Worker;
import com.navalgo.backend.worker.WorkerRepository;
import jakarta.persistence.EntityNotFoundException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;
import software.amazon.awssdk.core.sync.RequestBody;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.model.DeleteObjectRequest;
import software.amazon.awssdk.services.s3.model.PutObjectRequest;

import javax.imageio.IIOImage;
import javax.imageio.ImageIO;
import javax.imageio.ImageWriteParam;
import javax.imageio.ImageWriter;
import javax.imageio.stream.ImageOutputStream;
import java.awt.*;
import java.awt.image.BufferedImage;
import java.io.*;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;
import java.time.format.DateTimeFormatter;
import java.text.Normalizer;
import java.util.Iterator;
import java.util.Locale;
import java.util.UUID;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

@Service
@Transactional(readOnly = true)
public class WorkOrderMediaService {

    private static final Logger log = LoggerFactory.getLogger(WorkOrderMediaService.class);

    private static final DateTimeFormatter DATE_FORMATTER = DateTimeFormatter.ISO_LOCAL_DATE;

    private final S3Client s3Client;
    private final MediaProperties mediaProperties;
    private final WorkerRepository workerRepository;
    private final UploadValidationService uploadValidationService;

    public WorkOrderMediaService(S3Client s3Client,
                                 MediaProperties mediaProperties,
                                 WorkerRepository workerRepository,
                                 UploadValidationService uploadValidationService) {
        this.s3Client = s3Client;
        this.mediaProperties = mediaProperties;
        this.workerRepository = workerRepository;
        this.uploadValidationService = uploadValidationService;
    }

    public UploadedAttachmentDto uploadMedia(MultipartFile file,
                                             Double latitude,
                                             Double longitude,
                                             Instant capturedAt,
                                             String uploaderEmail) {
        return uploadWorkOrderAttachment(file, latitude, longitude, capturedAt, uploaderEmail,
            null, null, null);
    }

        public UploadedAttachmentDto uploadWorkOrderAttachment(MultipartFile file,
                                   Double latitude,
                                   Double longitude,
                                   Instant capturedAt,
                                   String uploaderEmail,
                                   String ownerName,
                                   String vesselName,
                                   LocalDate workOrderDate) {
        String basePath = buildWorkOrderBasePath(ownerName, vesselName, workOrderDate);
        return uploadMedia(file, latitude, longitude, capturedAt, uploaderEmail,
            true, true, basePath + "/adjuntos", true);
        }

        public UploadedAttachmentDto uploadSignature(MultipartFile file,
                             Double latitude,
                             Double longitude,
                             Instant capturedAt,
                             String uploaderEmail,
                             String ownerName,
                             String vesselName,
                             LocalDate workOrderDate) {
        String basePath = buildWorkOrderBasePath(ownerName, vesselName, workOrderDate);
        return uploadMedia(file, latitude, longitude, capturedAt, uploaderEmail,
            false, true, basePath + "/firma", false);
    }

    public UploadedAttachmentDto uploadProfilePhoto(MultipartFile file,
                                                    String uploaderEmail) {
        uploadValidationService.validateProfilePhoto(file);
        String emailFolder = sanitizeSegment(uploaderEmail == null ? "usuario" : uploaderEmail.toLowerCase(Locale.ROOT));
        String basePath = "usuarios/" + emailFolder + "/perfil";
        return uploadMedia(file, null, null, null, uploaderEmail,
            false, false, basePath, false);
    }

    private UploadedAttachmentDto uploadMedia(MultipartFile file,
                                              Double latitude,
                                              Double longitude,
                                              Instant capturedAt,
                                              String uploaderEmail,
                                              boolean applyWatermark,
                              boolean includeMetadata,
                              String keyPrefix,
                              boolean allowVideo) {
        if (file == null || file.isEmpty()) {
            throw new IllegalArgumentException("El archivo es obligatorio");
        }

        if (allowVideo) {
            uploadValidationService.validateWorkOrderAttachment(file, true);
        } else if (applyWatermark) {
            uploadValidationService.validateWorkOrderAttachment(file, false);
        } else {
            uploadValidationService.validateSignature(file);
        }

        Worker worker = workerRepository.findByEmailIgnoreCase(uploaderEmail)
                .orElseThrow(() -> new EntityNotFoundException("Usuario no encontrado"));

        String contentType = file.getContentType() == null ? "" : file.getContentType().toLowerCase(Locale.ROOT);
        Instant capturedInstant = capturedAt == null ? Instant.now() : capturedAt;

        try {
            if (contentType.startsWith("image/")) {
                String imageKey = buildObjectKey(keyPrefix, ".jpg");
                return processAndUploadImage(
                        file,
                        worker,
                        latitude,
                        longitude,
                        capturedInstant,
                        applyWatermark,
                        includeMetadata,
                        imageKey
                );
            }
            if (contentType.startsWith("video/")) {
                if (!allowVideo) {
                    throw new IllegalArgumentException("Este tipo de archivo no esta permitido para este flujo");
                }
                String videoKey = buildObjectKey(keyPrefix, resolveVideoExtension(file));
                return processAndUploadVideo(file, worker, latitude, longitude, capturedInstant, videoKey);
            }
        } catch (IOException e) {
            throw new IllegalStateException("No se pudo procesar el archivo multimedia", e);
        }

        throw new IllegalArgumentException("Solo se permiten imagenes y videos");
    }

    private UploadedAttachmentDto processAndUploadImage(MultipartFile file,
                                                        Worker worker,
                                                        Double latitude,
                                                        Double longitude,
                                                        Instant capturedAt,
                                                        boolean applyWatermark,
                                                        boolean includeMetadata,
                                                        String objectKey) throws IOException {
        BufferedImage original = ImageIO.read(file.getInputStream());
        if (original == null) {
            throw new IllegalArgumentException("Formato de imagen no soportado");
        }

        BufferedImage rgbImage = new BufferedImage(original.getWidth(), original.getHeight(), BufferedImage.TYPE_INT_RGB);
        Graphics2D g2 = rgbImage.createGraphics();
        g2.drawImage(original, 0, 0, null);

        if (applyWatermark) {
            String watermarkText = buildWatermarkText(worker.getFullName(), capturedAt, latitude, longitude);
            drawWatermark(g2, rgbImage.getWidth(), rgbImage.getHeight(), watermarkText);
        }
        g2.dispose();

        ByteArrayOutputStream output = new ByteArrayOutputStream();
        writeCompressedJpeg(rgbImage, output);

        uploadToSpaces(objectKey, output.toByteArray(), "image/jpeg");

        return new UploadedAttachmentDto(
            buildPublicUrl(objectKey),
                "IMAGE",
                file.getOriginalFilename(),
            includeMetadata ? capturedAt : null,
            includeMetadata ? latitude : null,
            includeMetadata ? longitude : null,
            applyWatermark,
                false
        );
    }

    private UploadedAttachmentDto processAndUploadVideo(MultipartFile file,
                                                        Worker worker,
                                                        Double latitude,
                                                        Double longitude,
                                                        Instant capturedAt,
                                                        String objectKey) throws IOException {
        Path inputFile = Files.createTempFile("navalgo-upload-", ".mp4");
        Path outputFile = Files.createTempFile("navalgo-upload-processed-", ".mp4");
        byte[] originalBytes = file.getBytes();
        String originalContentType = file.getContentType() == null || file.getContentType().isBlank()
            ? "video/mp4"
            : file.getContentType();

        try {
            file.transferTo(inputFile);

            ProcessBuilder builder = new ProcessBuilder(
                    "ffmpeg",
                    "-y",
                    "-i", inputFile.toAbsolutePath().toString(),
                    "-an",
                    "-c:v", "libx264",
                    "-preset", "medium",
                    "-crf", "24",
                    outputFile.toAbsolutePath().toString()
            );
            builder.redirectErrorStream(true);
            Process process = builder.start();
            String ffmpegOutput = new String(process.getInputStream().readAllBytes());
            int exit = waitFor(process);

            if (exit != 0) {
                log.warn("Fallo ffmpeg al procesar video, se sube el original. Salida: {}", ffmpegOutput);
                uploadToSpaces(objectKey, originalBytes, originalContentType);
                return new UploadedAttachmentDto(
                        buildPublicUrl(objectKey),
                        "VIDEO",
                        file.getOriginalFilename(),
                        capturedAt,
                        latitude,
                        longitude,
                        false,
                        false
                );
            }

            byte[] bytes = Files.readAllBytes(outputFile);
                uploadToSpaces(objectKey, bytes, "video/mp4");

            return new UploadedAttachmentDto(
                    buildPublicUrl(objectKey),
                    "VIDEO",
                    file.getOriginalFilename(),
                    capturedAt,
                    latitude,
                    longitude,
                    false,
                    true
            );
        } finally {
            Files.deleteIfExists(inputFile);
            Files.deleteIfExists(outputFile);
        }
    }

    private void drawWatermark(Graphics2D g2, int width, int height, String text) {
        g2.setRenderingHint(RenderingHints.KEY_ANTIALIASING, RenderingHints.VALUE_ANTIALIAS_ON);
        int fontSize = Math.max(16, width / 45);
        g2.setFont(new Font("SansSerif", Font.BOLD, fontSize));

        FontMetrics fm = g2.getFontMetrics();
        int textWidth = fm.stringWidth(text);
        int textHeight = fm.getHeight();

        int x = width - textWidth - 24;
        int y = height - 24;

        g2.setColor(new Color(0, 0, 0, 150));
        g2.fillRoundRect(x - 12, y - textHeight, textWidth + 20, textHeight + 8, 12, 12);

        g2.setColor(new Color(255, 255, 255, 220));
        g2.drawString(text, x, y);
    }

    private void writeCompressedJpeg(BufferedImage image, OutputStream output) throws IOException {
        Iterator<ImageWriter> writers = ImageIO.getImageWritersByFormatName("jpg");
        if (!writers.hasNext()) {
            throw new IllegalStateException("No hay writer JPEG disponible");
        }

        ImageWriter writer = writers.next();
        try (ImageOutputStream imageOutput = ImageIO.createImageOutputStream(output)) {
            writer.setOutput(imageOutput);
            ImageWriteParam params = writer.getDefaultWriteParam();
            if (params.canWriteCompressed()) {
                params.setCompressionMode(ImageWriteParam.MODE_EXPLICIT);
                params.setCompressionQuality(0.82f);
            }
            writer.write(null, new IIOImage(image, null, null), params);
        } finally {
            writer.dispose();
        }
    }

    private void uploadToSpaces(String key, byte[] bytes, String contentType) {
        PutObjectRequest request = PutObjectRequest.builder()
                .bucket(mediaProperties.spacesBucket())
                .key(key)
                .contentType(contentType)
            .acl("public-read")
                .build();

        s3Client.putObject(request, RequestBody.fromBytes(bytes));
    }

    private String buildObjectKey(String keyPrefix, String extension) {
        return keyPrefix + "/" + UUID.randomUUID() + extension;
    }

    private String resolveVideoExtension(MultipartFile file) {
        String originalName = file.getOriginalFilename();
        if (originalName != null) {
            int dotIndex = originalName.lastIndexOf('.');
            if (dotIndex >= 0 && dotIndex < originalName.length() - 1) {
                String ext = originalName.substring(dotIndex).toLowerCase(Locale.ROOT);
                if (ext.matches("\\.(mp4|mov|avi|m4v|webm)")) {
                    return ext;
                }
            }
        }
        return ".mp4";
    }

    private String buildWorkOrderBasePath(String ownerName, String vesselName, LocalDate workOrderDate) {
        String ownerFolder = sanitizeSegment(ownerName == null ? "sin-cliente" : ownerName);
        String vesselFolder = sanitizeSegment(vesselName == null ? "sin-embarcacion" : vesselName);
        LocalDate date = workOrderDate == null ? LocalDate.now() : workOrderDate;
        return "adjuntos-partes/" + ownerFolder + "/" + vesselFolder + "/" + DATE_FORMATTER.format(date);
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

    private String buildWatermarkText(String workerName, Instant capturedAt, Double latitude, Double longitude) {
        String ts = DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss")
                .withZone(ZoneId.systemDefault())
                .format(capturedAt);

        String location = (latitude == null || longitude == null)
                ? "GPS:N/D"
                : "GPS:" + String.format(Locale.ROOT, "%.5f,%.5f", latitude, longitude);

        return "NavalGO | " + workerName + " | " + ts + " | " + location;
    }

    private int waitFor(Process process) {
        try {
            return process.waitFor();
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            throw new IllegalStateException("Proceso de video interrumpido", e);
        }
    }

    public void deleteByPublicUrl(String fileUrl) {
        if (fileUrl == null || fileUrl.isBlank()) {
            return;
        }

        String base = mediaProperties.publicBaseUrl();
        if (base == null || base.isBlank()) {
            return;
        }

        String normalizedBase = base.endsWith("/") ? base : base + "/";
        if (!fileUrl.startsWith(normalizedBase)) {
            return;
        }

        String key = fileUrl.substring(normalizedBase.length());
        if (key.isBlank()) {
            return;
        }

        DeleteObjectRequest request = DeleteObjectRequest.builder()
                .bucket(mediaProperties.spacesBucket())
                .key(key)
                .build();
        try {
            s3Client.deleteObject(request);
        } catch (Exception exception) {
            log.warn("No se pudo borrar el objeto {} del almacenamiento: {}", key, exception.getMessage());
        }
    }
}
