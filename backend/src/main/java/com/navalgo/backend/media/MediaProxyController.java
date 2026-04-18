package com.navalgo.backend.media;

import org.springframework.core.io.InputStreamResource;
import org.springframework.http.CacheControl;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
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
    public ResponseEntity<InputStreamResource> proxy(@RequestParam("url") String fileUrl) {
        MediaProxyService.MediaStream media = mediaProxyService.loadFromPublicUrl(fileUrl);

        MediaType contentType;
        try {
            contentType = media.contentType() == null || media.contentType().isBlank()
                    ? MediaType.APPLICATION_OCTET_STREAM
                    : MediaType.parseMediaType(media.contentType());
        } catch (IllegalArgumentException exception) {
            contentType = MediaType.APPLICATION_OCTET_STREAM;
        }

        ResponseEntity.BodyBuilder responseBuilder = ResponseEntity.ok()
                .cacheControl(CacheControl.maxAge(Duration.ofHours(1)).cachePublic())
                .contentType(contentType);

        if (media.contentLength() != null && media.contentLength() > 0) {
            responseBuilder.contentLength(media.contentLength());
        }

        return responseBuilder.body(new InputStreamResource(media.stream()));
    }
}