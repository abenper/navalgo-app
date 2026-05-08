package com.navalgo.backend.media;

import org.springframework.core.io.InputStreamResource;
import org.springframework.http.CacheControl;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.time.Duration;
import java.util.regex.Pattern;

@RestController
@RequestMapping("/api/media")
public class MediaProxyController {
    private static final Pattern SINGLE_RANGE_PATTERN = Pattern.compile("^bytes=\\d*-\\d*$");

    private final MediaProxyService mediaProxyService;

    public MediaProxyController(MediaProxyService mediaProxyService) {
        this.mediaProxyService = mediaProxyService;
    }

    @GetMapping("/proxy")
    @PreAuthorize("hasAnyRole('ADMIN','COMERCIAL','WORKER')")
    public ResponseEntity<InputStreamResource> proxy(
            @RequestParam("url") String fileUrl,
            @RequestHeader(value = HttpHeaders.RANGE, required = false) String rangeHeader) {
        validateRangeHeader(rangeHeader);

        MediaProxyService.MediaStream media = mediaProxyService.loadFromPublicUrl(fileUrl, rangeHeader);

        MediaType contentType;
        try {
            contentType = media.contentType() == null || media.contentType().isBlank()
                    ? MediaType.APPLICATION_OCTET_STREAM
                    : MediaType.parseMediaType(media.contentType());
        } catch (IllegalArgumentException exception) {
            contentType = MediaType.APPLICATION_OCTET_STREAM;
        }

        boolean isRangeRequest = rangeHeader != null && !rangeHeader.isBlank();

        ResponseEntity.BodyBuilder responseBuilder = ResponseEntity
                .status(isRangeRequest ? HttpStatus.PARTIAL_CONTENT : HttpStatus.OK)
                .header(HttpHeaders.ACCEPT_RANGES, "bytes")
                .header("X-Content-Type-Options", "nosniff")
                .cacheControl(CacheControl.maxAge(Duration.ZERO).cachePrivate().mustRevalidate().noTransform())
                .contentType(contentType);

        if (media.contentLength() != null && media.contentLength() > 0) {
            responseBuilder.contentLength(media.contentLength());
        }

        if (isRangeRequest && media.contentRange() != null && !media.contentRange().isBlank()) {
            responseBuilder.header(HttpHeaders.CONTENT_RANGE, media.contentRange());
        }

        return responseBuilder.body(new InputStreamResource(media.stream()));
    }

    private void validateRangeHeader(String rangeHeader) {
        if (rangeHeader == null || rangeHeader.isBlank()) {
            return;
        }
        String normalized = rangeHeader.trim();
        if (normalized.length() > 64 || !SINGLE_RANGE_PATTERN.matcher(normalized).matches()) {
            throw new IllegalArgumentException("La cabecera Range no es valida");
        }
    }
}
