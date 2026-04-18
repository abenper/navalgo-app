package com.navalgo.backend.workorder;

import com.navalgo.backend.media.MediaProperties;
import com.navalgo.backend.media.UploadValidationService;
import com.navalgo.backend.worker.Worker;
import com.navalgo.backend.worker.WorkerRepository;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.mock.web.MockMultipartFile;
import software.amazon.awssdk.awscore.exception.AwsErrorDetails;
import software.amazon.awssdk.core.sync.RequestBody;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.model.PutObjectRequest;
import software.amazon.awssdk.services.s3.model.S3Exception;

import java.time.Instant;
import java.time.LocalDate;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.argThat;
import static org.mockito.Mockito.doNothing;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class WorkOrderMediaServiceTest {

    @Mock
    private S3Client s3Client;

    @Mock
    private WorkerRepository workerRepository;

    @Mock
    private UploadValidationService uploadValidationService;

    @Test
    void uploadProfilePhotoRetriesWithoutAclWhenStorageRejectsAcl() {
        WorkOrderMediaService service = new WorkOrderMediaService(
                s3Client,
                new MediaProperties(
                        "https://fra1.digitaloceanspaces.com",
                        "fra1",
                        "navalgo-media",
                        "key",
                        "secret",
                        "https://media.naval-go.com"
                ),
                workerRepository,
                uploadValidationService
        );
        MockMultipartFile file = new MockMultipartFile(
                "file",
                "perfil.png",
                "image/png",
                tinyPng()
        );

        doNothing().when(uploadValidationService).validateProfilePhoto(file);
        doThrow(aclNotSupported())
                .when(s3Client)
                .putObject(
                        argThat((PutObjectRequest request) -> request.acl() != null),
                        any(RequestBody.class)
                );

        service.uploadProfilePhoto(file, "admin@navalgo.com");

        ArgumentCaptor<PutObjectRequest> requestCaptor = ArgumentCaptor.forClass(PutObjectRequest.class);
        verify(s3Client, times(2)).putObject(
                requestCaptor.capture(),
                any(RequestBody.class)
        );

        assertNotNull(requestCaptor.getAllValues().get(0).acl());
        assertNull(requestCaptor.getAllValues().get(1).acl());
        assertEquals("image/png", requestCaptor.getAllValues().get(0).contentType());
        assertEquals(true, requestCaptor.getAllValues().get(0).key().endsWith(".png"));
        assertEquals(
                requestCaptor.getAllValues().get(0).key(),
                requestCaptor.getAllValues().get(1).key()
        );
    }

    @Test
    void uploadSignatureStoresLosslessPng() {
        WorkOrderMediaService service = new WorkOrderMediaService(
                s3Client,
                new MediaProperties(
                        "https://fra1.digitaloceanspaces.com",
                        "fra1",
                        "navalgo-media",
                        "key",
                        "secret",
                        "https://media.naval-go.com"
                ),
                workerRepository,
                uploadValidationService
        );

        MockMultipartFile file = new MockMultipartFile(
                "file",
                "firma.png",
                "image/png",
                tinyPng()
        );
        Worker worker = new Worker();
        worker.setFullName("Mecanico Naval");

        doNothing().when(uploadValidationService).validateSignature(file);
        when(workerRepository.findByEmailIgnoreCase("worker@navalgo.com"))
                .thenReturn(Optional.of(worker));

        service.uploadSignature(
                file,
                36.5,
                -4.5,
                Instant.parse("2026-04-18T10:15:30Z"),
                "worker@navalgo.com",
                "Cliente",
                "Barco",
                LocalDate.of(2026, 4, 18)
        );

        ArgumentCaptor<PutObjectRequest> requestCaptor = ArgumentCaptor.forClass(PutObjectRequest.class);
        verify(s3Client).putObject(requestCaptor.capture(), any(RequestBody.class));

        assertEquals("image/png", requestCaptor.getValue().contentType());
        assertEquals(true, requestCaptor.getValue().key().endsWith(".png"));
    }

        private byte[] tinyPng() {
                return new byte[] {
                                (byte) 0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
                                0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
                                0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
                                0x08, 0x02, 0x00, 0x00, 0x00, (byte) 0x90, 0x77, 0x53,
                                (byte) 0xDE, 0x00, 0x00, 0x00, 0x0C, 0x49, 0x44, 0x41,
                                0x54, 0x08, (byte) 0xD7, 0x63, (byte) 0xF8, (byte) 0xFF, (byte) 0xFF, 0x3F,
                                0x00, 0x05, (byte) 0xFE, 0x02, (byte) 0xFE, 0x41, (byte) 0xE2, 0x28,
                                (byte) 0x9D, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E,
                                0x44, (byte) 0xAE, 0x42, 0x60, (byte) 0x82
                };
        }

    private S3Exception aclNotSupported() {
        return (S3Exception) S3Exception.builder()
                .statusCode(400)
                .awsErrorDetails(
                        AwsErrorDetails.builder()
                                .serviceName("s3")
                                .errorCode("AccessControlListNotSupported")
                                .errorMessage("ACLs are not supported")
                                .build()
                )
                .message("ACLs are not supported")
                .build();
    }
}