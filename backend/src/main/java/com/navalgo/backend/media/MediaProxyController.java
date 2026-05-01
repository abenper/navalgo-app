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

@RestController
@RequestMapping("/api/media")
public class MediaProxyController {

    private final MediaProxyService mediaProxyService;

    public MediaProxyController(MediaProxyService mediaProxyService) {
        this.mediaProxyService = mediaProxyService;
    }

    @GetMapping("/proxy")
    @PreAuthorize("hasAnyRole('ADMIN','WORKER')")
    public ResponseEntity<InputStreamResource> proxy(
            @RequestParam("url") String fileUrl,
            @RequestHeader(value = HttpHeaders.RANGE, required = false) String rangeHeader) {

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
                .cacheControl(CacheControl.maxAge(Duration.ofHours(1)).cachePublic())
                .contentType(contentType);

        if (media.contentLength() != null && media.contentLength() > 0) {
            responseBuilder.contentLength(media.contentLength());
        }

        if (isRangeRequest && media.contentRange() != null && !media.contentRange().isBlank()) {
            responseBuilder.header(HttpHeaders.CONTENT_RANGE, media.contentRange());
        }

        return responseBuilder.body(new InputStreamResource(media.stream()));
    }
}
