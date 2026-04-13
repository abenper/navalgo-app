package com.navalgo.backend.workorder;

import com.navalgo.backend.fleet.Owner;
import com.navalgo.backend.fleet.Vessel;
import com.navalgo.backend.worker.Worker;
import jakarta.persistence.*;

import java.time.Instant;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
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
    private List<EngineHourLog> engineHourLogs = new ArrayList<>();

    @OneToMany(mappedBy = "workOrder", cascade = CascadeType.ALL, orphanRemoval = true)
    private List<WorkOrderAttachment> attachments = new ArrayList<>();

    @Column(nullable = false)
    private Instant createdAt = Instant.now();

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

    public List<EngineHourLog> getEngineHourLogs() { return engineHourLogs; }
    public void setEngineHourLogs(List<EngineHourLog> engineHourLogs) { this.engineHourLogs = engineHourLogs; }

    public List<WorkOrderAttachment> getAttachments() { return attachments; }
    public void setAttachments(List<WorkOrderAttachment> attachments) { this.attachments = attachments; }

    public Instant getCreatedAt() { return createdAt; }
    public void setCreatedAt(Instant createdAt) { this.createdAt = createdAt; }
}
