package com.navalgo.backend.workorder;

import com.navalgo.backend.worker.Worker;
import jakarta.persistence.*;

import java.time.Instant;

@Entity
@Table(name = "material_revision_requests")
public class MaterialRevisionRequest {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "work_order_id", nullable = false)
    private WorkOrder workOrder;

    @Column(name = "checklist_item_snapshot_id")
    private Long checklistItemSnapshotId;

    @Column(name = "source_template_id")
    private Long sourceTemplateId;

    @Column(name = "source_template_item_id")
    private Long sourceTemplateItemId;

    @Column(name = "product_id")
    private Long productId;

    @Column(nullable = false, length = 255)
    private String articleName;

    @Column(name = "reference_code", nullable = false, length = 255)
    private String reference;

    @Column(nullable = false, length = 3000)
    private String observations;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 32)
    private MaterialRevisionRequestStatus status = MaterialRevisionRequestStatus.PENDING;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "requested_by_worker_id", nullable = false)
    private Worker requestedByWorker;

    @Column(nullable = false)
    private Instant createdAt = Instant.now();

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "reviewed_by_worker_id")
    private Worker reviewedByWorker;

    private Instant reviewedAt;

    @Column(length = 1000)
    private String resolutionNote;

    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }

    public WorkOrder getWorkOrder() { return workOrder; }
    public void setWorkOrder(WorkOrder workOrder) { this.workOrder = workOrder; }

    public Long getChecklistItemSnapshotId() { return checklistItemSnapshotId; }
    public void setChecklistItemSnapshotId(Long checklistItemSnapshotId) { this.checklistItemSnapshotId = checklistItemSnapshotId; }

    public Long getSourceTemplateId() { return sourceTemplateId; }
    public void setSourceTemplateId(Long sourceTemplateId) { this.sourceTemplateId = sourceTemplateId; }

    public Long getSourceTemplateItemId() { return sourceTemplateItemId; }
    public void setSourceTemplateItemId(Long sourceTemplateItemId) { this.sourceTemplateItemId = sourceTemplateItemId; }

    public Long getProductId() { return productId; }
    public void setProductId(Long productId) { this.productId = productId; }

    public String getArticleName() { return articleName; }
    public void setArticleName(String articleName) { this.articleName = articleName; }

    public String getReference() { return reference; }
    public void setReference(String reference) { this.reference = reference; }

    public String getObservations() { return observations; }
    public void setObservations(String observations) { this.observations = observations; }

    public MaterialRevisionRequestStatus getStatus() { return status; }
    public void setStatus(MaterialRevisionRequestStatus status) { this.status = status; }

    public Worker getRequestedByWorker() { return requestedByWorker; }
    public void setRequestedByWorker(Worker requestedByWorker) { this.requestedByWorker = requestedByWorker; }

    public Instant getCreatedAt() { return createdAt; }
    public void setCreatedAt(Instant createdAt) { this.createdAt = createdAt; }

    public Worker getReviewedByWorker() { return reviewedByWorker; }
    public void setReviewedByWorker(Worker reviewedByWorker) { this.reviewedByWorker = reviewedByWorker; }

    public Instant getReviewedAt() { return reviewedAt; }
    public void setReviewedAt(Instant reviewedAt) { this.reviewedAt = reviewedAt; }

    public String getResolutionNote() { return resolutionNote; }
    public void setResolutionNote(String resolutionNote) { this.resolutionNote = resolutionNote; }
}
