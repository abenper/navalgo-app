package com.navalgo.backend.budget;

import jakarta.persistence.*;

import java.time.Instant;

@Entity
@Table(name = "budget_events")
public class BudgetEvent {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(optional = false, fetch = FetchType.LAZY)
    @JoinColumn(name = "budget_id", nullable = false)
    private Budget budget;

    @Enumerated(EnumType.STRING)
    @Column(name = "event_type", nullable = false, length = 40)
    private BudgetEventType eventType;

    @Column(name = "actor_name", nullable = false, length = 255)
    private String actorName;

    @Column(name = "actor_role", nullable = false, length = 40)
    private String actorRole;

    @Column(name = "event_note", length = 2000)
    private String note;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt;

    public Long getId() {
        return id;
    }

    public void setId(Long id) {
        this.id = id;
    }

    public Budget getBudget() {
        return budget;
    }

    public void setBudget(Budget budget) {
        this.budget = budget;
    }

    public BudgetEventType getEventType() {
        return eventType;
    }

    public void setEventType(BudgetEventType eventType) {
        this.eventType = eventType;
    }

    public String getActorName() {
        return actorName;
    }

    public void setActorName(String actorName) {
        this.actorName = actorName;
    }

    public String getActorRole() {
        return actorRole;
    }

    public void setActorRole(String actorRole) {
        this.actorRole = actorRole;
    }

    public String getNote() {
        return note;
    }

    public void setNote(String note) {
        this.note = note;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }

    public void setCreatedAt(Instant createdAt) {
        this.createdAt = createdAt;
    }
}
