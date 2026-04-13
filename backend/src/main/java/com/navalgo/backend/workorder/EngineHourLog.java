package com.navalgo.backend.workorder;

import jakarta.persistence.*;

@Entity
@Table(name = "engine_hour_logs")
public class EngineHourLog {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(optional = false, fetch = FetchType.LAZY)
    private WorkOrder workOrder;

    @Column(nullable = false)
    private String engineLabel;

    @Column(nullable = false)
    private Integer hours;

    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }

    public WorkOrder getWorkOrder() { return workOrder; }
    public void setWorkOrder(WorkOrder workOrder) { this.workOrder = workOrder; }

    public String getEngineLabel() { return engineLabel; }
    public void setEngineLabel(String engineLabel) { this.engineLabel = engineLabel; }

    public Integer getHours() { return hours; }
    public void setHours(Integer hours) { this.hours = hours; }
}
