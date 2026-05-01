package com.navalgo.backend.workorder;

import com.navalgo.backend.worker.Worker;
import jakarta.persistence.*;

import java.time.Instant;

@Entity
@Table(name = "work_order_checklist_items")
public class WorkOrderChecklistItem {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "checklist_id", nullable = false)
    private WorkOrderChecklist checklist;

    @Column(name = "source_template_item_id")
    private Long sourceTemplateItemId;

    @Column(name = "product_id")
    private Long productId;

    @Column(nullable = false, length = 255)
    private String articleName;

    @Column(name = "reference_code", nullable = false, length = 255)
    private String reference;

    @Column(nullable = false)
    private boolean checked;

    private Instant checkedAt;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "checked_by_worker_id")
    private Worker checkedByWorker;

    @Column(nullable = false)
    private int sortOrder;

    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }

    public WorkOrderChecklist getChecklist() { return checklist; }
    public void setChecklist(WorkOrderChecklist checklist) { this.checklist = checklist; }

    public Long getSourceTemplateItemId() { return sourceTemplateItemId; }
    public void setSourceTemplateItemId(Long sourceTemplateItemId) { this.sourceTemplateItemId = sourceTemplateItemId; }

    public Long getProductId() { return productId; }
    public void setProductId(Long productId) { this.productId = productId; }

    public String getArticleName() { return articleName; }
    public void setArticleName(String articleName) { this.articleName = articleName; }

    public String getReference() { return reference; }
    public void setReference(String reference) { this.reference = reference; }

    public boolean isChecked() { return checked; }
    public void setChecked(boolean checked) { this.checked = checked; }

    public Instant getCheckedAt() { return checkedAt; }
    public void setCheckedAt(Instant checkedAt) { this.checkedAt = checkedAt; }

    public Worker getCheckedByWorker() { return checkedByWorker; }
    public void setCheckedByWorker(Worker checkedByWorker) { this.checkedByWorker = checkedByWorker; }

    public int getSortOrder() { return sortOrder; }
    public void setSortOrder(int sortOrder) { this.sortOrder = sortOrder; }
}
