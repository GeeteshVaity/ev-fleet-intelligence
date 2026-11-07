package com.evfleet.backend.config;

import java.time.Duration;

import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import software.amazon.awssdk.regions.Region;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.presigner.S3Presigner;

@Configuration
@ConditionalOnProperty(name = "app.s3.enabled", havingValue = "true")
public class S3Config {

    @Bean
    S3Client s3Client(S3Properties properties) {
        return S3Client.builder()
                .region(Region.of(properties.region()))
                .build();
    }

    @Bean
    S3Presigner s3Presigner(S3Properties properties) {
        return S3Presigner.builder()
                .region(Region.of(properties.region()))
                .build();
    }

    @Bean
    S3Properties s3Properties(
            @org.springframework.beans.factory.annotation.Value("${app.s3.bucket}") String bucket,
            @org.springframework.beans.factory.annotation.Value("${app.s3.region}") String region,
            @org.springframework.beans.factory.annotation.Value("${app.s3.presign-expiry-seconds}") long expirySeconds) {
        if (bucket.isBlank()) {
            throw new IllegalStateException("S3_BUCKET must be configured when S3 is enabled");
        }
        if (expirySeconds < 60 || expirySeconds > 3600) {
            throw new IllegalStateException("S3_PRESIGN_EXPIRY_SECONDS must be between 60 and 3600");
        }
        return new S3Properties(bucket, region, Duration.ofSeconds(expirySeconds));
    }

    public record S3Properties(String bucket, String region, Duration presignExpiry) {
    }
}
