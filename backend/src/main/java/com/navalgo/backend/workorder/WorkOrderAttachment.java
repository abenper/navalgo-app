package com.navalgo.backend.workorder;

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

    private String originalFileName;

    private Instant capturedAt;

    private Double latitude;

    private Double longitude;

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

    public String getOriginalFileName() { return originalFileName; }
    public void setOriginalFileName(String originalFileName) { this.originalFileName = originalFileName; }

    public Instant getCapturedAt() { return capturedAt; }
    public void setCapturedAt(Instant capturedAt) { this.capturedAt = capturedAt; }

    public Double getLatitude() { return latitude; }
    public void setLatitude(Double latitude) { this.latitude = latitude; }

    public Double getLongitude() { return longitude; }
    public void setLongitude(Double longitude) { this.longitude = longitude; }

    public boolean isWatermarked() { return watermarked; }
    public void setWatermarked(boolean watermarked) { this.watermarked = watermarked; }

    public boolean isAudioRemoved() { return audioRemoved; }
    public void setAudioRemoved(boolean audioRemoved) { this.audioRemoved = audioRemoved; }
}
