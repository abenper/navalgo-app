package com.navalgo.backend.timetracking;

import com.navalgo.backend.worker.Worker;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;

import java.time.Instant;
import java.time.LocalDate;

@Entity
@Table(name = "time_adjustment_requests")
public class TimeAdjustmentRequest {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(optional = false, fetch = FetchType.LAZY)
    @JoinColumn(name = "worker_id", nullable = false)
    private Worker worker;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "time_entry_id")
    private TimeEntry timeEntry;

    @Column(nullable = false)
    private LocalDate workDate;

    private Instant requestedClockIn;

    private Instant requestedClockOut;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private TimeEntryWorkSite workSite;

    @Column(nullable = false, length = 2000)
    private String reason;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private TimeAdjustmentRequestStatus status = TimeAdjustmentRequestStatus.PENDING;

    @Column(length = 1000)
    private String adminComment;

    @Column(nullable = false)
    private Instant createdAt = Instant.now();

    private Instant reviewedAt;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "reviewed_by_worker_id")
    private Worker reviewedByWorker;

    public Long getId() {
        return id;
    }

    public void setId(Long id) {
        this.id = id;
    }

    public Worker getWorker() {
        return worker;
    }

    public void setWorker(Worker worker) {
        this.worker = worker;
    }

    public TimeEntry getTimeEntry() {
        return timeEntry;
    }

    public void setTimeEntry(TimeEntry timeEntry) {
        this.timeEntry = timeEntry;
    }

    public LocalDate getWorkDate() {
        return workDate;
    }

    public void setWorkDate(LocalDate workDate) {
        this.workDate = workDate;
    }

    public Instant getRequestedClockIn() {
        return requestedClockIn;
    }

    public void setRequestedClockIn(Instant requestedClockIn) {
        this.requestedClockIn = requestedClockIn;
    }

    public Instant getRequestedClockOut() {
        return requestedClockOut;
    }

    public void setRequestedClockOut(Instant requestedClockOut) {
        this.requestedClockOut = requestedClockOut;
    }

    public TimeEntryWorkSite getWorkSite() {
        return workSite;
    }

    public void setWorkSite(TimeEntryWorkSite workSite) {
        this.workSite = workSite;
    }

    public String getReason() {
        return reason;
    }

    public void setReason(String reason) {
        this.reason = reason;
    }

    public TimeAdjustmentRequestStatus getStatus() {
        return status;
    }

    public void setStatus(TimeAdjustmentRequestStatus status) {
        this.status = status;
    }

    public String getAdminComment() {
        return adminComment;
    }

    public void setAdminComment(String adminComment) {
        this.adminComment = adminComment;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }

    public void setCreatedAt(Instant createdAt) {
        this.createdAt = createdAt;
    }

    public Instant getReviewedAt() {
        return reviewedAt;
    }

    public void setReviewedAt(Instant reviewedAt) {
        this.reviewedAt = reviewedAt;
    }

    public Worker getReviewedByWorker() {
        return reviewedByWorker;
    }

    public void setReviewedByWorker(Worker reviewedByWorker) {
        this.reviewedByWorker = reviewedByWorker;
    }
}