package com.navalgo.backend.workorder;

import com.navalgo.backend.fleet.Owner;
import com.navalgo.backend.fleet.Vessel;
import com.navalgo.backend.worker.Worker;
import jakarta.persistence.*;

import java.math.BigDecimal;
import java.time.Instant;
import java.time.LocalDate;
import java.util.HashSet;
import java.util.LinkedHashSet;
import java.util.Set;

@Entity
@Table(name = "work_orders")
public class WorkOrder {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private String title;

    @Column(length = 3000)
    private String description;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private WorkOrderStatus status = WorkOrderStatus.NEW;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private WorkOrderPriority priority = WorkOrderPriority.NORMAL;

    @ManyToOne(optional = false, fetch = FetchType.LAZY)
    private Owner owner;

    @ManyToOne(fetch = FetchType.LAZY)
    private Vessel vessel;

    @ManyToMany
    @JoinTable(
            name = "work_order_workers",
            joinColumns = @JoinColumn(name = "work_order_id"),
            inverseJoinColumns = @JoinColumn(name = "worker_id")
    )
    private Set<Worker> assignedWorkers = new HashSet<>();

    @OneToMany(mappedBy = "workOrder", cascade = CascadeType.ALL, orphanRemoval = true)
    private Set<EngineHourLog> engineHourLogs = new LinkedHashSet<>();

    @OneToMany(mappedBy = "workOrder", cascade = CascadeType.ALL, orphanRemoval = true)
    private Set<WorkOrderAttachment> attachments = new LinkedHashSet<>();

    @Column(precision = 8, scale = 2)
    private BigDecimal laborHours;

    @OneToOne(mappedBy = "workOrder", cascade = CascadeType.ALL, orphanRemoval = true)
    private WorkOrderChecklist materialChecklist;

    @OneToMany(mappedBy = "workOrder", cascade = CascadeType.ALL, orphanRemoval = true)
    private Set<MaterialRevisionRequest> materialRevisionRequests = new LinkedHashSet<>();

    @Column(name = "close_due_date")
    private LocalDate closeDueDate;

    @Column(nullable = false)
    private Instant createdAt = Instant.now();

    @Column(name = "last_close_reminder_sent_at")
    private Instant lastCloseReminderSentAt;

    @Column(length = 2000)
    private String signatureUrl;

    private Instant signedAt;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "signed_by_worker_id")
    private Worker signedByWorker;

    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }

    public String getTitle() { return title; }
    public void setTitle(String title) { this.title = title; }

    public String getDescription() { return description; }
    public void setDescription(String description) { this.description = description; }

    public WorkOrderStatus getStatus() { return status; }
    public void setStatus(WorkOrderStatus status) { this.status = status; }

    public WorkOrderPriority getPriority() { return priority; }
    public void setPriority(WorkOrderPriority priority) { this.priority = priority; }

    public Owner getOwner() { return owner; }
    public void setOwner(Owner owner) { this.owner = owner; }

    public Vessel getVessel() { return vessel; }
    public void setVessel(Vessel vessel) { this.vessel = vessel; }

    public Set<Worker> getAssignedWorkers() { return assignedWorkers; }
    public void setAssignedWorkers(Set<Worker> assignedWorkers) { this.assignedWorkers = assignedWorkers; }

    public Set<EngineHourLog> getEngineHourLogs() { return engineHourLogs; }
    public void setEngineHourLogs(Set<EngineHourLog> engineHourLogs) { this.engineHourLogs = engineHourLogs; }

    public Set<WorkOrderAttachment> getAttachments() { return attachments; }
    public void setAttachments(Set<WorkOrderAttachment> attachments) { this.attachments = attachments; }

    public BigDecimal getLaborHours() { return laborHours; }
    public void setLaborHours(BigDecimal laborHours) { this.laborHours = laborHours; }

    public WorkOrderChecklist getMaterialChecklist() { return materialChecklist; }
    public void setMaterialChecklist(WorkOrderChecklist materialChecklist) {
        this.materialChecklist = materialChecklist;
        if (materialChecklist != null) {
            materialChecklist.setWorkOrder(this);
        }
    }

    public Set<MaterialRevisionRequest> getMaterialRevisionRequests() { return materialRevisionRequests; }
    public void setMaterialRevisionRequests(Set<MaterialRevisionRequest> materialRevisionRequests) {
        this.materialRevisionRequests = materialRevisionRequests;
    }

    public LocalDate getCloseDueDate() { return closeDueDate; }
    public void setCloseDueDate(LocalDate closeDueDate) { this.closeDueDate = closeDueDate; }

    public Instant getCreatedAt() { return createdAt; }
    public void setCreatedAt(Instant createdAt) { this.createdAt = createdAt; }

    public Instant getLastCloseReminderSentAt() { return lastCloseReminderSentAt; }
    public void setLastCloseReminderSentAt(Instant lastCloseReminderSentAt) { this.lastCloseReminderSentAt = lastCloseReminderSentAt; }

    public String getSignatureUrl() { return signatureUrl; }
    public void setSignatureUrl(String signatureUrl) { this.signatureUrl = signatureUrl; }

    public Instant getSignedAt() { return signedAt; }
    public void setSignedAt(Instant signedAt) { this.signedAt = signedAt; }

    public Worker getSignedByWorker() { return signedByWorker; }
    public void setSignedByWorker(Worker signedByWorker) { this.signedByWorker = signedByWorker; }
}
