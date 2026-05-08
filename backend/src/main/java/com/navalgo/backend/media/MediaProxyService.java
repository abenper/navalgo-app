package com.navalgo.backend.media;

import org.springframework.stereotype.Service;
import software.amazon.awssdk.core.ResponseInputStream;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.model.GetObjectRequest;
import software.amazon.awssdk.services.s3.model.GetObjectResponse;

import java.net.URI;
import java.net.URLDecoder;
import java.nio.charset.StandardCharsets;
import java.util.Arrays;
import java.util.Locale;
import java.util.Objects;
import java.util.Set;
import java.util.stream.Collectors;

@Service
public class MediaProxyService {

    private final S3Client s3Client;
    private final MediaProperties mediaProperties;
    private final Set<String> allowedPrefixes;

    public MediaProxyService(S3Client s3Client, MediaProperties mediaProperties) {
        this.s3Client = s3Client;
        this.mediaProperties = mediaProperties;
        this.allowedPrefixes = Arrays.stream(
                        (mediaProperties.proxyAllowedPrefixes() == null ? "" : mediaProperties.proxyAllowedPrefixes())
                                .split(",")
                )
                .map(String::trim)
                .filter(prefix -> !prefix.isEmpty())
                .map(prefix -> prefix.endsWith("/") ? prefix : prefix + "/")
                .collect(Collectors.toUnmodifiableSet());
    }

    public MediaStream loadFromPublicUrl(String fileUrl) {
        return loadFromPublicUrl(fileUrl, null);
    }

    public MediaStream loadFromPublicUrl(String fileUrl, String rangeHeader) {
        String objectKey = extractObjectKey(fileUrl);
        GetObjectRequest.Builder requestBuilder = GetObjectRequest.builder()
                .bucket(mediaProperties.spacesBucket())
                .key(objectKey);

        if (rangeHeader != null && !rangeHeader.isBlank()) {
            requestBuilder.range(rangeHeader);
        }

        ResponseInputStream<GetObjectResponse> stream = s3Client.getObject(requestBuilder.build());

        GetObjectResponse response = stream.response();
        return new MediaStream(
                stream,
                response.contentType(),
                response.contentLength(),
                objectKey,
                response.contentRange()
        );
    }

    String extractObjectKey(String fileUrl) {
        if (fileUrl == null || fileUrl.isBlank()) {
            throw new IllegalArgumentException("La URL del archivo es obligatoria");
        }

        String publicBaseUrl = mediaProperties.publicBaseUrl();
        if (publicBaseUrl == null || publicBaseUrl.isBlank()) {
            throw new IllegalStateException("APP_MEDIA_PUBLIC_BASE_URL no esta configurado");
        }

        URI baseUri = URI.create(publicBaseUrl.trim());
        URI requestUri = URI.create(fileUrl.trim());

        if (!Objects.equals(normalizeScheme(baseUri.getScheme()), normalizeScheme(requestUri.getScheme()))
                || !Objects.equals(normalizeHost(baseUri.getHost()), normalizeHost(requestUri.getHost()))
                || normalizePort(baseUri) != normalizePort(requestUri)) {
            throw new IllegalArgumentException("La URL del archivo no pertenece al almacenamiento configurado");
        }

        String basePath = normalizePath(baseUri.getPath());
        String requestPath = normalizePath(requestUri.getPath());

        if (!basePath.isEmpty()) {
            if (!requestPath.equals(basePath) && !requestPath.startsWith(basePath + "/")) {
                throw new IllegalArgumentException("La URL del archivo no pertenece al almacenamiento configurado");
            }
            requestPath = requestPath.substring(basePath.length());
        }

        if (requestPath.startsWith("/")) {
            requestPath = requestPath.substring(1);
        }

        String objectKey = URLDecoder.decode(requestPath, StandardCharsets.UTF_8);
        if (objectKey.isBlank()) {
            throw new IllegalArgumentException("La URL del archivo no contiene una clave valida");
        }
        if (objectKey.contains("\\") || objectKey.contains("..")) {
            throw new IllegalArgumentException("La clave del archivo no es valida");
        }
        if (!isAllowedObjectKey(objectKey)) {
            throw new IllegalArgumentException("Ese archivo no esta autorizado para ser servido por el proxy");
        }

        return objectKey;
    }

    private boolean isAllowedObjectKey(String objectKey) {
        if (allowedPrefixes.isEmpty()) {
            return false;
        }
        for (String prefix : allowedPrefixes) {
            if (objectKey.startsWith(prefix)) {
                return true;
            }
        }
        return false;
    }

    private String normalizeScheme(String scheme) {
        return scheme == null ? "" : scheme.trim().toLowerCase(Locale.ROOT);
    }

    private String normalizeHost(String host) {
        return host == null ? "" : host.trim().toLowerCase(Locale.ROOT);
    }

    private int normalizePort(URI uri) {
        if (uri.getPort() != -1) {
            return uri.getPort();
        }

        return "https".equalsIgnoreCase(uri.getScheme()) ? 443 : 80;
    }

    private String normalizePath(String path) {
        if (path == null || path.isBlank() || "/".equals(path)) {
            return "";
        }

        String normalized = path.endsWith("/") ? path.substring(0, path.length() - 1) : path;
        return normalized.startsWith("/") ? normalized : "/" + normalized;
    }

    public record MediaStream(
            ResponseInputStream<GetObjectResponse> stream,
            String contentType,
            Long contentLength,
            String objectKey,
            String contentRange
    ) {
    }
}
