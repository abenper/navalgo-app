package com.navalgo.backend.workorder;

import com.navalgo.backend.worker.Worker;
import jakarta.persistence.*;

import java.time.Instant;

@Entity
@Table(name = "work_order_attachments")
public class WorkOrderAttachment {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(optional = false, fetch = FetchType.LAZY)
    private WorkOrder workOrder;

    @Column(nullable = false, length = 2000)
    private String fileUrl;

    @Column(nullable = false)
    private String fileType;

    @Column(length = 255)
    private String contentType;

    private String originalFileName;

    private Instant capturedAt;

    @Column(nullable = false)
    private Instant uploadedAt = Instant.now();

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "uploaded_by_worker_id")
    private Worker uploadedByWorker;

    private Double latitude;

    private Double longitude;

    @Column(name = "file_size_bytes")
    private Long fileSizeBytes;

    @Column(name = "storage_object_key", length = 2000)
    private String storageObjectKey;

    @Column(name = "sha256_hex", length = 64)
    private String sha256Hex;

    @Column(name = "server_signature", length = 128)
    private String serverSignature;

    @Column(name = "upload_ip", length = 128)
    private String uploadIp;

    @Column(name = "upload_user_agent", length = 1000)
    private String uploadUserAgent;

    @Column(nullable = false)
    private boolean watermarked = false;

    @Column(nullable = false)
    private boolean audioRemoved = false;

    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }

    public WorkOrder getWorkOrder() { return workOrder; }
    public void setWorkOrder(WorkOrder workOrder) { this.workOrder = workOrder; }

    public String getFileUrl() { return fileUrl; }
    public void setFileUrl(String fileUrl) { this.fileUrl = fileUrl; }

    public String getFileType() { return fileType; }
    public void setFileType(String fileType) { this.fileType = fileType; }

    public String getContentType() { return contentType; }
    public void setContentType(String contentType) { this.contentType = contentType; }

    public String getOriginalFileName() { return originalFileName; }
    public void setOriginalFileName(String originalFileName) { this.originalFileName = originalFileName; }

    public Instant getCapturedAt() { return capturedAt; }
    public void setCapturedAt(Instant capturedAt) { this.capturedAt = capturedAt; }

    public Instant getUploadedAt() { return uploadedAt; }
    public void setUploadedAt(Instant uploadedAt) { this.uploadedAt = uploadedAt; }

    public Worker getUploadedByWorker() { return uploadedByWorker; }
    public void setUploadedByWorker(Worker uploadedByWorker) { this.uploadedByWorker = uploadedByWorker; }

    public Double getLatitude() { return latitude; }
    public void setLatitude(Double latitude) { this.latitude = latitude; }

    public Double getLongitude() { return longitude; }
    public void setLongitude(Double longitude) { this.longitude = longitude; }

    public Long getFileSizeBytes() { return fileSizeBytes; }
    public void setFileSizeBytes(Long fileSizeBytes) { this.fileSizeBytes = fileSizeBytes; }

    public String getStorageObjectKey() { return storageObjectKey; }
    public void setStorageObjectKey(String storageObjectKey) { this.storageObjectKey = storageObjectKey; }

    public String getSha256Hex() { return sha256Hex; }
    public void setSha256Hex(String sha256Hex) { this.sha256Hex = sha256Hex; }

    public String getServerSignature() { return serverSignature; }
    public void setServerSignature(String serverSignature) { this.serverSignature = serverSignature; }

    public String getUploadIp() { return uploadIp; }
    public void setUploadIp(String uploadIp) { this.uploadIp = uploadIp; }

    public String getUploadUserAgent() { return uploadUserAgent; }
    public void setUploadUserAgent(String uploadUserAgent) { this.uploadUserAgent = uploadUserAgent; }

    public boolean isWatermarked() { return watermarked; }
    public void setWatermarked(boolean watermarked) { this.watermarked = watermarked; }

    public boolean isAudioRemoved() { return audioRemoved; }
    public void setAudioRemoved(boolean audioRemoved) { this.audioRemoved = audioRemoved; }
}
