package com.navalgo.backend.workorder;

import com.navalgo.backend.media.MediaProperties;
import com.navalgo.backend.media.UploadValidationService;
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

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.argThat;
import static org.mockito.Mockito.doNothing;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;

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
                new byte[] {1, 2, 3}
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
        assertEquals(
                requestCaptor.getAllValues().get(0).key(),
                requestCaptor.getAllValues().get(1).key()
        );
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