package com.syn.usermanagement.service;

import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;
import software.amazon.awssdk.core.sync.RequestBody;
import software.amazon.awssdk.regions.Region;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.model.DeleteObjectRequest;
import software.amazon.awssdk.services.s3.model.PutObjectRequest;
import software.amazon.awssdk.services.s3.presigner.S3Presigner;
import software.amazon.awssdk.services.s3.presigner.model.GetObjectPresignRequest;

import java.io.IOException;
import java.time.Duration;
import java.util.UUID;

/**
 * Talks to S3. The bucket is PRIVATE, so the browser gets a pre-signed URL:
 * a normal link that works for a limited time only.
 *
 * No access keys here: the AWS SDK finds credentials by itself
 * (on EC2 it uses the instance's IAM role).
 */
@Slf4j
@Service
public class PhotoStorageService {

    private final String bucket;
    private final Duration urlValidity;
    private final S3Client s3;
    private final S3Presigner presigner;

    public PhotoStorageService(@Value("${app.s3.bucket:}") String bucket,
                               @Value("${app.s3.region:ap-south-1}") String region,
                               @Value("${app.s3.presigned-url-minutes:60}") long urlMinutes) {
        this.bucket = bucket;
        this.urlValidity = Duration.ofMinutes(urlMinutes);

        if (bucket == null || bucket.isBlank()) {
            log.warn("S3_BUCKET is not set: photo upload is switched off");
            this.s3 = null;
            this.presigner = null;
        } else {
            Region awsRegion = Region.of(region);
            this.s3 = S3Client.builder().region(awsRegion).build();
            this.presigner = S3Presigner.builder().region(awsRegion).build();
            log.info("Photos will be stored in S3 bucket '{}' ({})", bucket, region);
        }
    }

    public boolean isEnabled() {
        return s3 != null;
    }

    /** Uploads the file and returns its S3 key, e.g. users/7/3f2a....png */
    public String upload(Long userId, MultipartFile file) throws IOException {
        String key = "users/" + userId + "/" + UUID.randomUUID() + extensionOf(file.getContentType());

        PutObjectRequest request = PutObjectRequest.builder()
                .bucket(bucket)
                .key(key)
                .contentType(file.getContentType())
                .build();
        // fromBytes (not fromInputStream): the SDK reads the body twice (checksum + upload,
        // and again on a retry). An upload stream can only be read once; bytes can be re-read.
        // Photos are max 5 MB, so keeping them in memory is fine.
        s3.putObject(request, RequestBody.fromBytes(file.getBytes()));

        log.info("Uploaded photo for user {} to s3://{}/{}", userId, bucket, key);
        return key;
    }

    public void delete(String key) {
        if (key == null || !isEnabled()) {
            return;
        }
        s3.deleteObject(DeleteObjectRequest.builder().bucket(bucket).key(key).build());
        log.info("Deleted old photo s3://{}/{}", bucket, key);
    }

    /** A temporary link to the photo, or null if there is no photo. */
    public String presignedUrl(String key) {
        if (key == null || !isEnabled()) {
            return null;
        }
        GetObjectPresignRequest request = GetObjectPresignRequest.builder()
                .signatureDuration(urlValidity)
                .getObjectRequest(get -> get.bucket(bucket).key(key))
                .build();
        return presigner.presignGetObject(request).url().toString();
    }

    private static String extensionOf(String contentType) {
        if ("image/png".equals(contentType)) {
            return ".png";
        }
        if ("image/webp".equals(contentType)) {
            return ".webp";
        }
        return ".jpg";
    }
}
