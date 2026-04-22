package com.navalgo.backend.workorder;

import jakarta.persistence.*;

import java.time.Instant;
import java.util.LinkedHashSet;
import java.util.Set;

@Entity
@Table(name = "work_order_checklists")
public class WorkOrderChecklist {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @OneToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "work_order_id", nullable = false, unique = true)
    private WorkOrder workOrder;

    @Column(name = "source_template_id")
    private Long sourceTemplateId;

    @Column(name = "source_template_name", nullable = false, length = 255)
    private String sourceTemplateName;

    @Column(nullable = false)
    private Instant assignedAt = Instant.now();

    @OneToMany(mappedBy = "checklist", cascade = CascadeType.ALL, orphanRemoval = true)
    @OrderBy("sortOrder ASC, id ASC")
    private Set<WorkOrderChecklistItem> items = new LinkedHashSet<>();

    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }

    public WorkOrder getWorkOrder() { return workOrder; }
    public void setWorkOrder(WorkOrder workOrder) { this.workOrder = workOrder; }

    public Long getSourceTemplateId() { return sourceTemplateId; }
    public void setSourceTemplateId(Long sourceTemplateId) { this.sourceTemplateId = sourceTemplateId; }

    public String getSourceTemplateName() { return sourceTemplateName; }
    public void setSourceTemplateName(String sourceTemplateName) { this.sourceTemplateName = sourceTemplateName; }

    public Instant getAssignedAt() { return assignedAt; }
    public void setAssignedAt(Instant assignedAt) { this.assignedAt = assignedAt; }

    public Set<WorkOrderChecklistItem> getItems() { return items; }
    public void setItems(Set<WorkOrderChecklistItem> items) { this.items = items; }
}