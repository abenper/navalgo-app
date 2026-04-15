package com.navalgo.backend.media;

import org.springframework.boot.context.properties.ConfigurationProperties;

@ConfigurationProperties(prefix = "app.media")
public record MediaProperties(
        String spacesEndpoint,
        String spacesRegion,
        String spacesBucket,
        String spacesAccessKey,
        String spacesSecretKey,
        String publicBaseUrl
) {
}
