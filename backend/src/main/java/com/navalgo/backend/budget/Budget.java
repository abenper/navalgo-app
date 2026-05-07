package com.navalgo.backend.budget;

import com.navalgo.backend.fleet.Owner;
import com.navalgo.backend.fleet.Vessel;
import com.navalgo.backend.worker.Worker;
import jakarta.persistence.*;

import java.math.BigDecimal;
import java.time.Instant;

@Entity
@Table(name = "budgets")
public class Budget {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(optional = false, fetch = FetchType.LAZY)
    private Owner owner;

    @ManyToOne(optional = false, fetch = FetchType.LAZY)
    private Vessel vessel;

    @ManyToOne(optional = false, fetch = FetchType.LAZY)
    @JoinColumn(name = "created_by_worker_id")
    private Worker createdByWorker;

    @Column(nullable = false)
    private String title;

    @Column(length = 3000)
    private String description;

    @Column(precision = 12, scale = 2)
    private BigDecimal amount;

    @Column(length = 3, nullable = false)
    private String currency;

    @Column(name = "pdf_url", nullable = false, length = 2000)
    private String pdfUrl;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private BudgetStatus status;

    @Column(name = "client_observations", length = 2000)
    private String clientObservations;

    @Column(name = "sent_at")
    private Instant sentAt;

    @Column(name = "client_decided_at")
    private Instant clientDecidedAt;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    public Long getId() {
        return id;
    }

    public void setId(Long id) {
        this.id = id;
    }

    public Owner getOwner() {
        return owner;
    }

    public void setOwner(Owner owner) {
        this.owner = owner;
    }

    public Vessel getVessel() {
        return vessel;
    }

    public void setVessel(Vessel vessel) {
        this.vessel = vessel;
    }

    public Worker getCreatedByWorker() {
        return createdByWorker;
    }

    public void setCreatedByWorker(Worker createdByWorker) {
        this.createdByWorker = createdByWorker;
    }

    public String getTitle() {
        return title;
    }

    public void setTitle(String title) {
        this.title = title;
    }

    public String getDescription() {
        return description;
    }

    public void setDescription(String description) {
        this.description = description;
    }

    public BigDecimal getAmount() {
        return amount;
    }

    public void setAmount(BigDecimal amount) {
        this.amount = amount;
    }

    public String getCurrency() {
        return currency;
    }

    public void setCurrency(String currency) {
        this.currency = currency;
    }

    public String getPdfUrl() {
        return pdfUrl;
    }

    public void setPdfUrl(String pdfUrl) {
        this.pdfUrl = pdfUrl;
    }

    public BudgetStatus getStatus() {
        return status;
    }

    public void setStatus(BudgetStatus status) {
        this.status = status;
    }

    public String getClientObservations() {
        return clientObservations;
    }

    public void setClientObservations(String clientObservations) {
        this.clientObservations = clientObservations;
    }

    public Instant getSentAt() {
        return sentAt;
    }

    public void setSentAt(Instant sentAt) {
        this.sentAt = sentAt;
    }

    public Instant getClientDecidedAt() {
        return clientDecidedAt;
    }

    public void setClientDecidedAt(Instant clientDecidedAt) {
        this.clientDecidedAt = clientDecidedAt;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }

    public void setCreatedAt(Instant createdAt) {
        this.createdAt = createdAt;
    }

    public Instant getUpdatedAt() {
        return updatedAt;
    }

    public void setUpdatedAt(Instant updatedAt) {
        this.updatedAt = updatedAt;
    }
}
