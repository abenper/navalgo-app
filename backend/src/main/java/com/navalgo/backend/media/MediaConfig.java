package com.navalgo.backend.media;

import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import software.amazon.awssdk.auth.credentials.AwsBasicCredentials;
import software.amazon.awssdk.auth.credentials.StaticCredentialsProvider;
import software.amazon.awssdk.regions.Region;
import software.amazon.awssdk.services.s3.S3Client;

import java.net.URI;

@Configuration
@EnableConfigurationProperties(MediaProperties.class)
public class MediaConfig {

    @Bean
    public S3Client s3Client(MediaProperties mediaProperties) {
        return S3Client.builder()
                .endpointOverride(URI.create(mediaProperties.spacesEndpoint()))
                .region(Region.of(mediaProperties.spacesRegion()))
                .credentialsProvider(StaticCredentialsProvider.create(
                        AwsBasicCredentials.create(
                                mediaProperties.spacesAccessKey(),
                                mediaProperties.spacesSecretKey()
                        )
                ))
                .forcePathStyle(false)
                .build();
    }
}
