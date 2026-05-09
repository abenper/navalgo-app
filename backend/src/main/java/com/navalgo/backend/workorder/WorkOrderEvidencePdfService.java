package com.navalgo.backend.workorder;

import org.apache.pdfbox.pdmodel.PDDocument;
import org.apache.pdfbox.pdmodel.PDPage;
import org.apache.pdfbox.pdmodel.PDPageContentStream;
import org.apache.pdfbox.pdmodel.common.PDRectangle;
import org.apache.pdfbox.pdmodel.font.PDType1Font;
import org.apache.pdfbox.pdmodel.font.Standard14Fonts;
import org.apache.pdfbox.pdmodel.graphics.image.LosslessFactory;
import org.apache.pdfbox.pdmodel.graphics.image.PDImageXObject;
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

    private static final float MARGIN = 44f;
    private static final float LOGO_MAX_WIDTH = 132f;
    private static final float LOGO_MAX_HEIGHT = 42f;

    private static final PDType1Font BODY_FONT = new PDType1Font(Standard14Fonts.FontName.HELVETICA);
    private static final PDType1Font BODY_BOLD_FONT = new PDType1Font(Standard14Fonts.FontName.HELVETICA_BOLD);
    private static final PDType1Font BODY_ITALIC_FONT = new PDType1Font(Standard14Fonts.FontName.HELVETICA_OBLIQUE);

    private static final Color INK = new Color(11, 31, 42);
    private static final Color DEEP_SEA = new Color(16, 54, 69);
    private static final Color TIDE = new Color(20, 85, 104);
    private static final Color HARBOR = new Color(28, 114, 130);
    private static final Color STORM = new Color(96, 119, 132);
    private static final Color CORAL = new Color(214, 109, 74);

    private static final DateTimeFormatter DATE_TIME_FORMATTER = DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss z")
            .withZone(ZoneId.systemDefault());

    public byte[] buildReport(WorkOrder workOrder) {
        try (PDDocument document = new PDDocument()) {
            List<DocLine> lines = buildLines(workOrder);
            writeLines(document, lines, workOrder);
            ByteArrayOutputStream output = new ByteArrayOutputStream();
            document.save(output);
            return output.toByteArray();
        } catch (IOException exception) {
            throw new IllegalStateException("No se pudo generar el acta de integridad PDF", exception);
        }
    }

    private List<DocLine> buildLines(WorkOrder workOrder) {
        List<DocLine> lines = new ArrayList<>();

        lines.add(kicker("USO INTERNO ADMINISTRATIVO"));
        lines.add(body(
                "Este documento resume la cadena de custodia técnica de las evidencias del parte. " +
                        "No se limita a listar archivos: describe qué datos quedaron sellados, " +
                        "qué hash se calculó sobre cada binario y qué firma HMAC emitió el servidor."
        ));
        lines.add(body(
                "La clave secreta empleada para las firmas HMAC nunca se incorpora al PDF ni se expone al cliente. " +
                        "Permanece únicamente en el backend para que la verificación dependa del servidor."
        ));

        lines.add(section("1. Qué acredita esta acta"));
        lines.add(body(
                "Acredita que, en el momento del sellado final del parte, existía un conjunto concreto de adjuntos, " +
                        "con unos metadatos concretos y con unos resúmenes criptográficos concretos."
        ));
        lines.add(body(
                "Si posteriormente alguien sustituyera un archivo, alterara sus bytes, cambiara fechas, geolocalización, " +
                        "usuario de subida, ruta de almacenamiento o cualquier otro dato sellado, el resultado dejaría de coincidir " +
                        "con los hash y firmas consignados aquí."
        ));

        lines.add(section("2. Guía de lectura de campos"));
        lines.add(subsection("2.1 Campos de sellado del parte"));
        addFieldExplanation(lines, "ID del parte",
                "Identificador interno único del parte dentro del sistema.");
        addFieldExplanation(lines, "Título",
                "Descripción corta con la que se identifica operativamente el parte.");
        addFieldExplanation(lines, "Estado",
                "Situación funcional del parte en el momento del sellado.");
        addFieldExplanation(lines, "Prioridad",
                "Nivel operativo asignado al parte para su gestión.");
        addFieldExplanation(lines, "Propietario",
                "Cliente o entidad titular asociada al parte.");
        addFieldExplanation(lines, "Embarcación",
                "Unidad naval vinculada al trabajo, si existe.");
        addFieldExplanation(lines, "Creado",
                "Fecha y hora de alta del parte en la plataforma.");
        addFieldExplanation(lines, "Firmado",
                "Fecha y hora en la que el parte quedó firmado y pasó a estado cerrado.");
        addFieldExplanation(lines, "Firmado por",
                "Usuario responsable del cierre del parte en el sistema.");
        addFieldExplanation(lines, "Firma de cliente",
                "Momento en el que se registró la firma de cliente, si existe. Este dato forma parte del contexto auditado del parte.");
        addFieldExplanation(lines, "Sellado final de evidencia",
                "Instante exacto en el que el backend cerró el manifiesto técnico del parte y dejó la evidencia bloqueada.");
        addFieldExplanation(lines, "Hash del manifiesto sellado",
                "SHA-256 calculado sobre el manifiesto completo del parte en el instante del sellado. " +
                        "El manifiesto incluye datos del parte y el payload firmado de todos los adjuntos, ordenados de forma estable.");
        addFieldExplanation(lines, "Firma HMAC del sellado",
                "HMAC-SHA256 calculada por el servidor sobre el mismo manifiesto sellado, usando una clave secreta que no sale del backend.");

        lines.add(subsection("2.2 Campos de cada adjunto"));
        addFieldExplanation(lines, "ID interno",
                "Identificador único del adjunto dentro del parte.");
        addFieldExplanation(lines, "Nombre original",
                "Nombre del archivo informado en el momento de la subida.");
        addFieldExplanation(lines, "Tipo",
                "Clasificación funcional del adjunto, por ejemplo imagen o vídeo.");
        addFieldExplanation(lines, "MIME",
                "Tipo de contenido técnico detectado o almacenado para el fichero.");
        addFieldExplanation(lines, "URL pública",
                "Ruta pública desde la que se sirve el adjunto almacenado.");
        addFieldExplanation(lines, "Clave de almacenamiento",
                "Ruta interna o clave del objeto persistido en almacenamiento. Se usa para identificar qué binario concreto quedó sellado.");
        addFieldExplanation(lines, "Tamaño en bytes",
                "Peso exacto del archivo final sellado.");
        addFieldExplanation(lines, "Hash SHA-256 del archivo",
                "Resumen criptográfico calculado sobre los bytes exactos del archivo final almacenado. " +
                        "Si cambia un solo byte, el hash resultante cambia por completo.");
        addFieldExplanation(lines, "Firma HMAC del adjunto",
                "HMAC-SHA256 emitida por el servidor sobre el payload técnico del adjunto. " +
                        "No firma solo la imagen: firma también sus metadatos sellados.");
        addFieldExplanation(lines, "Capturado",
                "Marca temporal informada por la captura del adjunto.");
        addFieldExplanation(lines, "Subido en servidor",
                "Marca temporal en la que el backend recibió y registró el adjunto.");
        addFieldExplanation(lines, "GPS",
                "Coordenadas asociadas al adjunto en el momento de la captura o subida, si fueron informadas.");
        addFieldExplanation(lines, "Marca de agua aplicada",
                "Indica si el backend generó el archivo final con superposición visible de contexto operativo.");
        addFieldExplanation(lines, "Audio eliminado",
                "Indica si el backend eliminó la pista de audio del vídeo antes de almacenar la evidencia final.");
        addFieldExplanation(lines, "IP de subida / User-Agent",
                "Contexto técnico de recepción en backend para reforzar trazabilidad de origen.");
        addFieldExplanation(lines, "Usuario que adjuntó / Email / ID del usuario",
                "Identidad interna del usuario que originó la subida, si quedó registrada.");

        lines.add(section("3. Cómo garantiza el sistema la integridad"));
        lines.add(subsection("3.1 Hash del binario final almacenado"));
        lines.add(body(
                "El backend calcula un SHA-256 sobre los bytes exactos del archivo final que queda almacenado. " +
                        "Ese valor no es decorativo: representa el contenido binario real, byte a byte."
        ));
        lines.add(body(
                "Si la imagen o el vídeo se modifican más tarde, aunque el cambio sea mínimo, el hash ya no coincide con el consignado en esta acta."
        ));

        lines.add(subsection("3.2 Firma HMAC de cada adjunto"));
        lines.add(body(
                "Después del hash del archivo, el backend calcula una firma HMAC-SHA256 sobre un payload ordenado del adjunto. " +
                        "Ese payload incluye, entre otros, los siguientes campos:"
        ));
        lines.add(bullet(
                "workOrderId, attachmentId, fileUrl, storageObjectKey, fileType, contentType, originalFileName, " +
                        "sha256Hex, fileSizeBytes, capturedAt, uploadedAt, latitude, longitude, watermarked, audioRemoved, " +
                        "uploadIp, uploadUserAgent, uploadedByWorkerId y uploadedByWorkerEmail."
        ));
        lines.add(body(
                "Esto significa que no solo queda protegido el binario: también queda protegida la relación entre el binario y sus metadatos sellados."
        ));

        lines.add(subsection("3.3 Hash y firma del manifiesto completo"));
        lines.add(body(
                "Cuando el parte se cierra, el backend construye un manifiesto completo y ordenado con los datos del parte " +
                        "y con el payload firmado de todos los adjuntos."
        ));
        lines.add(body(
                "Sobre ese manifiesto calcula dos valores distintos:"
        ));
        lines.add(bullet("Un SHA-256 del manifiesto completo, que identifica el estado exacto del conjunto sellado."));
        lines.add(bullet("Una firma HMAC-SHA256 del mismo manifiesto, emitida por el servidor con su clave secreta."));

        lines.add(subsection("3.4 Bloqueo posterior al sellado"));
        lines.add(body(
                "Una vez firmado y sellado, el backend deja de admitir cambios sobre la evidencia del parte. " +
                        "No se pueden añadir, sustituir ni borrar adjuntos sin romper la coherencia del sellado."
        ));
        lines.add(body(
                "Por eso, la garantía no descansa en una nota visual del PDF. Descansa en dos mecanismos acumulativos: " +
                        "los hash SHA-256 de los binarios y las firmas HMAC emitidas por el servidor sobre los datos sellados."
        ));

        lines.add(section("4. Resumen del parte sellado"));
        addDataField(lines, "ID del parte", safe(workOrder.getId()));
        addDataField(lines, "Título", safe(workOrder.getTitle()));
        addDataField(lines, "Estado", safe(workOrder.getStatus()));
        addDataField(lines, "Prioridad", safe(workOrder.getPriority()));
        addDataField(lines, "Propietario", workOrder.getOwner() != null ? safe(workOrder.getOwner().getDisplayName()) : "N/D");
        addDataField(lines, "Embarcación", workOrder.getVessel() != null ? safe(workOrder.getVessel().getName()) : "N/D");
        addDataField(lines, "Creado", formatInstant(workOrder.getCreatedAt()));
        addDataField(lines, "Firmado", formatInstant(workOrder.getSignedAt()));
        addDataField(lines, "Firmado por", workOrder.getSignedByWorker() != null ? safe(workOrder.getSignedByWorker().getFullName()) : "N/D");
        addDataField(lines, "Firma de cliente", formatInstant(workOrder.getClientSignedAt()));
        addDataField(lines, "Sellado final de evidencia", formatInstant(workOrder.getEvidenceSealedAt()));
        addDataField(lines, "Hash del manifiesto sellado", safe(workOrder.getEvidenceManifestHash()));
        addDataField(lines, "Firma HMAC del sellado", safe(workOrder.getEvidenceServerSignature()));

        lines.add(section("5. Evidencias incluidas en el sellado"));

        List<WorkOrderAttachment> attachments = workOrder.getAttachments().stream()
                .sorted(Comparator
                        .comparing(WorkOrderAttachment::getUploadedAt, Comparator.nullsLast(Comparator.naturalOrder()))
                        .thenComparing(WorkOrderAttachment::getId, Comparator.nullsLast(Comparator.naturalOrder()))
                        .thenComparing(WorkOrderAttachment::getFileUrl, Comparator.nullsLast(String::compareTo)))
                .toList();

        int index = 1;
        for (WorkOrderAttachment attachment : attachments) {
            lines.add(subsection("Adjunto " + index++));
            addDataField(lines, "ID interno", safe(attachment.getId()));
            addDataField(lines, "Nombre original", safe(attachment.getOriginalFileName()));
            addDataField(lines, "Tipo", safe(attachment.getFileType()));
            addDataField(lines, "MIME", safe(attachment.getContentType()));
            addDataField(lines, "URL pública", safe(attachment.getFileUrl()));
            addDataField(lines, "Clave de almacenamiento", safe(attachment.getStorageObjectKey()));
            addDataField(lines, "Tamaño en bytes", safe(attachment.getFileSizeBytes()));
            addDataField(lines, "Hash SHA-256 del archivo", safe(attachment.getSha256Hex()));
            addDataField(lines, "Firma HMAC del adjunto", safe(attachment.getServerSignature()));
            addDataField(lines, "Subido en servidor", formatInstant(attachment.getUploadedAt()));
            addDataField(lines, "Capturado", formatInstant(attachment.getCapturedAt()));
            addDataField(lines, "GPS", formatGps(attachment.getLatitude(), attachment.getLongitude()));
            addDataField(lines, "Marca de agua aplicada", boolLabel(attachment.isWatermarked()));
            addDataField(lines, "Audio eliminado", boolLabel(attachment.isAudioRemoved()));
            addDataField(lines, "IP de subida", safe(attachment.getUploadIp()));
            addDataField(lines, "User-Agent de subida", safe(attachment.getUploadUserAgent()));
            if (attachment.getUploadedByWorker() != null) {
                addDataField(lines, "Usuario que adjuntó", safe(attachment.getUploadedByWorker().getFullName()));
                addDataField(lines, "Email del usuario", safe(attachment.getUploadedByWorker().getEmail()));
                addDataField(lines, "ID del usuario", safe(attachment.getUploadedByWorker().getId()));
            } else {
                addDataField(lines, "Usuario que adjuntó", "N/D");
            }
        }

        lines.add(section("6. Criterio de lectura forense"));
        lines.add(body(
                "La coincidencia de un archivo con esta acta no se decide por nombre ni por apariencia visual. " +
                        "Se decide comparando el SHA-256 del binario y verificando, en backend, que las firmas HMAC del adjunto y del manifiesto " +
                        "siguen siendo válidas para el conjunto de datos sellado."
        ));
        lines.add(body(
                "Si cualquiera de esos valores deja de coincidir, debe considerarse que la evidencia presentada no es exactamente la que quedó sellada."
        ));

        return lines;
    }

    private void addFieldExplanation(List<DocLine> lines, String label, String description) {
        lines.add(labelLine(label));
        lines.add(valueLine(description));
    }

    private void addDataField(List<DocLine> lines, String label, String value) {
        lines.add(labelLine(label));
        lines.add(valueLine(value));
    }

    private DocLine kicker(String text) {
        return new DocLine(text, BODY_BOLD_FONT, 10.5f, CORAL, 4f, 14f, 0f);
    }

    private DocLine section(String text) {
        return new DocLine(text, BODY_BOLD_FONT, 13f, DEEP_SEA, 14f, 16f, 0f);
    }

    private DocLine subsection(String text) {
        return new DocLine(text, BODY_BOLD_FONT, 11.5f, TIDE, 10f, 15f, 0f);
    }

    private DocLine body(String text) {
        return new DocLine(text, BODY_FONT, 10.4f, INK, 4f, 14f, 0f);
    }

    private DocLine bullet(String text) {
        return new DocLine("- " + text, BODY_FONT, 10.4f, INK, 2f, 14f, 10f);
    }

    private DocLine labelLine(String text) {
        return new DocLine(text, BODY_BOLD_FONT, 10.4f, HARBOR, 6f, 13f, 0f);
    }

    private DocLine valueLine(String text) {
        return new DocLine(text, BODY_FONT, 10.2f, INK, 0f, 14f, 10f);
    }

    private void writeLines(PDDocument document, List<DocLine> lines, WorkOrder workOrder) throws IOException {
        PageCursor pageCursor = openPage(document, workOrder);
        float availableWidth = pageCursor.page().getMediaBox().getWidth() - (MARGIN * 2);

        for (DocLine line : lines) {
            List<String> wrappedLines = wrapLine(
                    line.text(),
                    line.font(),
                    line.fontSize(),
                    availableWidth - line.indent()
            );
            float requiredHeight = line.topSpacing() + (wrappedLines.size() * line.lineHeight());
            if (pageCursor.y() - requiredHeight <= MARGIN) {
                pageCursor.contentStream().close();
                pageCursor = openPage(document, workOrder);
            }

            float y = pageCursor.y() - line.topSpacing();
            for (String wrapped : wrappedLines) {
                if (!wrapped.isBlank()) {
                    pageCursor.contentStream().beginText();
                    pageCursor.contentStream().setFont(line.font(), line.fontSize());
                    pageCursor.contentStream().setNonStrokingColor(line.color());
                    pageCursor.contentStream().newLineAtOffset(MARGIN + line.indent(), y);
                    pageCursor.contentStream().showText(wrapped);
                    pageCursor.contentStream().endText();
                }
                y -= line.lineHeight();
            }
            pageCursor = pageCursor.withY(y);
        }

        pageCursor.contentStream().close();
    }

    private PageCursor openPage(PDDocument document, WorkOrder workOrder) throws IOException {
        PDPage page = new PDPage(PDRectangle.A4);
        document.addPage(page);
        PDPageContentStream contentStream = new PDPageContentStream(document, page);
        float y = renderPageHeader(document, page, contentStream, workOrder);
        return new PageCursor(page, contentStream, y);
    }

    private List<String> wrapLine(String line, PDType1Font font, float fontSize, float maxWidth) throws IOException {
        if (line == null || line.isBlank()) {
            return List.of("");
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
        return result.isEmpty() ? List.of("") : result;
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

        float titleX = MARGIN + logoWidth + (logoWidth > 0 ? 14f : 0f);
        float titleY = y - 8f;

        contentStream.beginText();
        contentStream.setFont(BODY_BOLD_FONT, 18f);
        contentStream.setNonStrokingColor(DEEP_SEA);
        contentStream.newLineAtOffset(titleX, titleY);
        contentStream.showText("Acta de integridad y cadena de custodia");
        contentStream.newLineAtOffset(0, -20f);
        contentStream.setFont(BODY_ITALIC_FONT, 10.2f);
        contentStream.setNonStrokingColor(STORM);
        contentStream.showText("Parte " + safe(workOrder.getId()) + " - Evidencia sellada por backend");
        contentStream.endText();

        float lineY = y - Math.max(logoHeight, 40f) - 10f;
        contentStream.setStrokingColor(HARBOR);
        contentStream.setLineWidth(1.2f);
        contentStream.moveTo(MARGIN, lineY);
        contentStream.lineTo(pageWidth - MARGIN, lineY);
        contentStream.stroke();

        return lineY - 16f;
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
        return value ? "Sí" : "No";
    }

    private String safe(Object value) {
        if (value == null) {
            return "N/D";
        }
        String raw = value.toString().trim();
        return raw.isEmpty() ? "N/D" : raw;
    }

    private record DocLine(
            String text,
            PDType1Font font,
            float fontSize,
            Color color,
            float topSpacing,
            float lineHeight,
            float indent
    ) {
    }

    private record PageCursor(
            PDPage page,
            PDPageContentStream contentStream,
            float y
    ) {
        private PageCursor withY(float newY) {
            return new PageCursor(page, contentStream, newY);
        }
    }
}
