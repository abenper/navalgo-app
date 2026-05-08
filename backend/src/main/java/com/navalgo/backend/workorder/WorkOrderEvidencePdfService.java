package com.navalgo.backend.workorder;

import org.apache.pdfbox.pdmodel.PDDocument;
import org.apache.pdfbox.pdmodel.PDPage;
import org.apache.pdfbox.pdmodel.PDPageContentStream;
import org.apache.pdfbox.pdmodel.common.PDRectangle;
import org.apache.pdfbox.pdmodel.font.PDType1Font;
import org.apache.pdfbox.pdmodel.font.Standard14Fonts;
import org.apache.pdfbox.pdmodel.graphics.image.LosslessFactory;
import org.springframework.stereotype.Service;

import javax.imageio.ImageIO;
import java.awt.Color;
import java.awt.image.BufferedImage;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.time.Instant;
import java.time.ZoneId;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.Locale;

@Service
public class WorkOrderEvidencePdfService {

    private static final float MARGIN = 46f;
    private static final float FONT_SIZE = 10.5f;
    private static final float HEADER_FONT_SIZE = 18f;
    private static final float SECTION_FONT_SIZE = 12f;
    private static final float LEADING = 14f;
    private static final float LOGO_MAX_WIDTH = 120f;
    private static final float LOGO_MAX_HEIGHT = 40f;
    private static final Color HEADER_COLOR = new Color(0, 82, 155);
    private static final Color SUBTITLE_COLOR = new Color(90, 90, 90);
    private static final PDType1Font BODY_FONT = new PDType1Font(Standard14Fonts.FontName.HELVETICA);
    private static final PDType1Font HEADER_FONT = new PDType1Font(Standard14Fonts.FontName.HELVETICA_BOLD);
    private static final PDType1Font SECTION_FONT = new PDType1Font(Standard14Fonts.FontName.HELVETICA_BOLD);
    private static final DateTimeFormatter DATE_TIME_FORMATTER = DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss z")
            .withZone(ZoneId.systemDefault());

    public byte[] buildReport(WorkOrder workOrder) {
        try (PDDocument document = new PDDocument()) {
            List<String> lines = buildLines(workOrder);
            writeLines(document, lines, workOrder);
            ByteArrayOutputStream output = new ByteArrayOutputStream();
            document.save(output);
            return output.toByteArray();
        } catch (IOException exception) {
            throw new IllegalStateException("No se pudo generar el informe probatorio PDF", exception);
        }
    }

    private List<String> buildLines(WorkOrder workOrder) {
        List<String> lines = new ArrayList<>();
        lines.add("Informe probatorio de adjuntos del parte");
        lines.add("");
        lines.add("Este documento resume la cadena de custodia de los archivos multimedia asociados al parte.");
        lines.add("Incluye autor de la subida, tiempos, geolocalizacion informada, huellas SHA-256 y sellos HMAC del servidor.");
        lines.add("");
        lines.add("Datos del parte");
        lines.add("ID: " + safe(workOrder.getId()));
        lines.add("Titulo: " + safe(workOrder.getTitle()));
        lines.add("Estado: " + safe(workOrder.getStatus()));
        lines.add("Prioridad: " + safe(workOrder.getPriority()));
        lines.add("Propietario: " + (workOrder.getOwner() != null ? safe(workOrder.getOwner().getDisplayName()) : "N/D"));
        lines.add("Embarcacion: " + (workOrder.getVessel() != null ? safe(workOrder.getVessel().getName()) : "N/D"));
        lines.add("Creado: " + formatInstant(workOrder.getCreatedAt()));
        lines.add("Firmado: " + formatInstant(workOrder.getSignedAt()));
        lines.add("Firmado por: " + (workOrder.getSignedByWorker() != null ? safe(workOrder.getSignedByWorker().getFullName()) : "N/D"));
        lines.add("Firma cliente: " + formatInstant(workOrder.getClientSignedAt()));
        lines.add("Sellado final de evidencia: " + formatInstant(workOrder.getEvidenceSealedAt()));
        lines.add("Hash manifiesto del parte: " + safe(workOrder.getEvidenceManifestHash()));
        lines.add("Firma HMAC del servidor: " + safe(workOrder.getEvidenceServerSignature()));
        lines.add("");
        lines.add("Advertencia de integridad");
        lines.add("Una vez firmado y sellado, el parte queda bloqueado en la aplicacion para evitar alteraciones de la evidencia.");
        lines.add("");
        lines.add("Adjuntos");

        List<WorkOrderAttachment> attachments = workOrder.getAttachments().stream()
                .sorted(Comparator
                        .comparing(WorkOrderAttachment::getUploadedAt, Comparator.nullsLast(Comparator.naturalOrder()))
                        .thenComparing(WorkOrderAttachment::getId, Comparator.nullsLast(Comparator.naturalOrder())))
                .toList();

        int index = 1;
        for (WorkOrderAttachment attachment : attachments) {
            lines.add("");
            lines.add("Adjunto " + index++);
            lines.add("ID: " + safe(attachment.getId()));
            lines.add("Nombre original: " + safe(attachment.getOriginalFileName()));
            lines.add("Tipo: " + safe(attachment.getFileType()));
            lines.add("MIME: " + safe(attachment.getContentType()));
            lines.add("URL publica: " + safe(attachment.getFileUrl()));
            lines.add("Clave de almacenamiento: " + safe(attachment.getStorageObjectKey()));
            lines.add("Tamano en bytes: " + safe(attachment.getFileSizeBytes()));
            lines.add("Hash SHA-256: " + safe(attachment.getSha256Hex()));
            lines.add("Firma HMAC del servidor: " + safe(attachment.getServerSignature()));
            lines.add("Subido en servidor: " + formatInstant(attachment.getUploadedAt()));
            lines.add("Capturado: " + formatInstant(attachment.getCapturedAt()));
            lines.add("GPS: " + formatGps(attachment.getLatitude(), attachment.getLongitude()));
            lines.add("Marca de agua aplicada: " + boolLabel(attachment.isWatermarked()));
            lines.add("Audio eliminado: " + boolLabel(attachment.isAudioRemoved()));
            lines.add("IP de subida: " + safe(attachment.getUploadIp()));
            lines.add("User-Agent de subida: " + safe(attachment.getUploadUserAgent()));
            if (attachment.getUploadedByWorker() != null) {
                lines.add("Usuario que adjunto: " + safe(attachment.getUploadedByWorker().getFullName()));
                lines.add("Email del usuario: " + safe(attachment.getUploadedByWorker().getEmail()));
                lines.add("ID del usuario: " + safe(attachment.getUploadedByWorker().getId()));
            } else {
                lines.add("Usuario que adjunto: N/D");
            }
        }
        return lines;
    }

    private void writeLines(PDDocument document, List<String> lines, WorkOrder workOrder) throws IOException {
        PDPage page = new PDPage(PDRectangle.A4);
        document.addPage(page);
        PDPageContentStream contentStream = new PDPageContentStream(document, page);
        float width = page.getMediaBox().getWidth() - (MARGIN * 2);
        float y = renderPageHeader(document, page, contentStream, workOrder);

        contentStream.setFont(BODY_FONT, FONT_SIZE);
        contentStream.setNonStrokingColor(Color.BLACK);
        contentStream.beginText();
        contentStream.newLineAtOffset(MARGIN, y);

        for (String line : lines) {
            boolean heading = isSectionHeading(line);
            PDType1Font font = heading ? SECTION_FONT : BODY_FONT;
            float fontSize = heading ? SECTION_FONT_SIZE : FONT_SIZE;
            List<String> wrappedLines = wrapLine(line, font, fontSize, width);
            for (String wrapped : wrappedLines) {
                if (y <= MARGIN) {
                    contentStream.endText();
                    contentStream.close();
                    page = new PDPage(PDRectangle.A4);
                    document.addPage(page);
                    contentStream = new PDPageContentStream(document, page);
                    y = renderPageHeader(document, page, contentStream, workOrder);
                    contentStream.setFont(BODY_FONT, FONT_SIZE);
                    contentStream.setNonStrokingColor(Color.BLACK);
                    contentStream.beginText();
                    contentStream.newLineAtOffset(MARGIN, y);
                }
                contentStream.setFont(font, fontSize);
                contentStream.showText(wrapped);
                contentStream.newLineAtOffset(0, -LEADING);
                y -= LEADING;
            }
        }

        contentStream.endText();
        contentStream.close();
    }

    private List<String> wrapLine(String line, PDType1Font font, float fontSize, float maxWidth) throws IOException {
        if (line == null || line.isBlank()) {
            return List.of(" ");
        }

        List<String> result = new ArrayList<>();
        String[] words = line.split("\\s+");
        StringBuilder current = new StringBuilder();
        for (String word : words) {
            String candidate = current.isEmpty() ? word : current + " " + word;
            float candidateWidth = font.getStringWidth(candidate) / 1000 * fontSize;
            if (current.isEmpty() || candidateWidth <= maxWidth) {
                current = new StringBuilder(candidate);
            } else {
                result.add(current.toString());
                current = new StringBuilder(word);
            }
        }
        if (!current.isEmpty()) {
            result.add(current.toString());
        }
        return result.isEmpty() ? List.of(" ") : result;
    }

    private float renderPageHeader(PDDocument document, PDPage page, PDPageContentStream contentStream, WorkOrder workOrder) throws IOException {
        float pageWidth = page.getMediaBox().getWidth();
        float pageHeight = page.getMediaBox().getHeight();
        float y = pageHeight - MARGIN;

        PDImageXObject logo = loadHeaderLogo(document);
        float logoWidth = 0f;
        float logoHeight = 0f;
        if (logo != null) {
            float imageWidth = logo.getWidth();
            float imageHeight = logo.getHeight();
            float scale = Math.min(LOGO_MAX_WIDTH / imageWidth, LOGO_MAX_HEIGHT / imageHeight);
            logoWidth = imageWidth * scale;
            logoHeight = imageHeight * scale;
            contentStream.drawImage(logo, MARGIN, y - logoHeight, logoWidth, logoHeight);
        }

        float titleX = MARGIN + logoWidth + (logoWidth > 0 ? 12f : 0f);
        float titleY = y - 10f;
        contentStream.beginText();
        contentStream.setFont(HEADER_FONT, HEADER_FONT_SIZE);
        contentStream.setNonStrokingColor(HEADER_COLOR);
        contentStream.newLineAtOffset(titleX, titleY);
        contentStream.showText("Informe probatorio");
        contentStream.newLineAtOffset(0, -HEADER_FONT_SIZE - 4f);
        contentStream.setFont(BODY_FONT, FONT_SIZE);
        contentStream.setNonStrokingColor(SUBTITLE_COLOR);
        contentStream.showText("Documento oficial de evidencia del parte firmado");
        contentStream.endText();

        float lineY = y - Math.max(logoHeight, HEADER_FONT_SIZE + 18f) - 12f;
        contentStream.setStrokingColor(HEADER_COLOR);
        contentStream.setLineWidth(1f);
        contentStream.moveTo(MARGIN, lineY);
        contentStream.lineTo(pageWidth - MARGIN, lineY);
        contentStream.stroke();

        return lineY - 18f;
    }

    private PDImageXObject loadHeaderLogo(PDDocument document) throws IOException {
        try (InputStream stream = getClass().getResourceAsStream("/logo_navalgo_horizontal.png")) {
            if (stream == null) {
                return null;
            }
            BufferedImage image = ImageIO.read(stream);
            if (image == null) {
                return null;
            }
            return LosslessFactory.createFromImage(document, image);
        }
    }

    private boolean isSectionHeading(String line) {
        return line != null && (line.equals("Datos del parte") || line.equals("Advertencia de integridad") || line.equals("Adjuntos") || line.startsWith("Adjunto "));
    }

    private String formatInstant(Instant instant) {
        return instant == null ? "N/D" : DATE_TIME_FORMATTER.format(instant);
    }

    private String formatGps(Double latitude, Double longitude) {
        if (latitude == null || longitude == null) {
            return "N/D";
        }
        return String.format(Locale.ROOT, "%.6f, %.6f", latitude, longitude);
    }

    private String boolLabel(boolean value) {
        return value ? "Si" : "No";
    }

    private String safe(Object value) {
        if (value == null) {
            return "N/D";
        }
        String raw = value.toString().trim();
        return raw.isEmpty() ? "N/D" : raw;
    }
}
