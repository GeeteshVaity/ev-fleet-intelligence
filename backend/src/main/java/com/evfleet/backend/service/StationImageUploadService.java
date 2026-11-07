package com.evfleet.backend.service;

import java.net.URI;
import java.time.Instant;
import java.util.UUID;

import org.springframework.stereotype.Service;

import com.evfleet.backend.config.S3Config.S3Properties;

import software.amazon.awssdk.services.s3.model.PutObjectRequest;
import software.amazon.awssdk.services.s3.presigner.S3Presigner;
import software.amazon.awssdk.services.s3.presigner.model.PresignedPutObjectRequest;
import software.amazon.awssdk.services.s3.presigner.model.PutObjectPresignRequest;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;

@Service
@ConditionalOnProperty(name = "app.s3.enabled", havingValue = "true")
public class StationImageUploadService {
    private final S3Presigner presigner;
    private final S3Properties properties;

    public StationImageUploadService(S3Presigner presigner, S3Properties properties) {
        this.presigner = presigner;
        this.properties = properties;
    }

    public PresignedUpload createUpload(Long stationId, String contentType) {
        String normalizedType = contentType == null ? "" : contentType.trim().toLowerCase();
        if (!normalizedType.matches("image/(jpeg|png|webp)")) {
            throw new IllegalArgumentException("Only JPEG, PNG, and WebP images are supported");
        }

        String objectKey = "stations/" + stationId + "/" + UUID.randomUUID() + extension(normalizedType);
        PutObjectRequest putObject = PutObjectRequest.builder()
                .bucket(properties.bucket())
                .key(objectKey)
                .contentType(normalizedType)
                .build();
        PutObjectPresignRequest request = PutObjectPresignRequest.builder()
                .signatureDuration(properties.presignExpiry())
                .putObjectRequest(putObject)
                .build();
        PresignedPutObjectRequest signed = presigner.presignPutObject(request);
        return new PresignedUpload(
                objectKey,
                URI.create(signed.url().toString()),
                Instant.now().plus(properties.presignExpiry()));
    }

    private String extension(String contentType) {
        return switch (contentType) {
            case "image/jpeg" -> ".jpg";
            case "image/png" -> ".png";
            default -> ".webp";
        };
    }

    public record PresignedUpload(String objectKey, URI uploadUrl, Instant expiresAt) {
    }
}
