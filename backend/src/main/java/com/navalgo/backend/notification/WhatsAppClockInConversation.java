package com.navalgo.backend.notification;

import com.navalgo.backend.timetracking.TimeEntry;
import com.navalgo.backend.worker.Worker;
import jakarta.persistence.*;

import java.time.Instant;
import java.time.LocalDate;

@Entity
@Table(name = "whatsapp_clock_in_conversations")
public class WhatsAppClockInConversation {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(optional = false, fetch = FetchType.LAZY)
    @JoinColumn(name = "worker_id", nullable = false)
    private Worker worker;

    @Column(name = "reminder_date", nullable = false)
    private LocalDate reminderDate;

    @Column(name = "phone_number", nullable = false, length = 32)
    private String phoneNumber;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 32)
    private WhatsAppClockInConversationState state = WhatsAppClockInConversationState.AWAITING_TIME;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "time_entry_id")
    private TimeEntry timeEntry;

    @Column(nullable = false)
    private Instant requestedAt = Instant.now();

    private Instant clockInRecordedAt;

    private Instant locationRequestedAt;

    private Instant completedAt;

    private Instant lastInboundAt;

    @Column(length = 32)
    private String rawClockInText;

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

    public LocalDate getReminderDate() {
        return reminderDate;
    }

    public void setReminderDate(LocalDate reminderDate) {
        this.reminderDate = reminderDate;
    }

    public String getPhoneNumber() {
        return phoneNumber;
    }

    public void setPhoneNumber(String phoneNumber) {
        this.phoneNumber = phoneNumber;
    }

    public WhatsAppClockInConversationState getState() {
        return state;
    }

    public void setState(WhatsAppClockInConversationState state) {
        this.state = state;
    }

    public TimeEntry getTimeEntry() {
        return timeEntry;
    }

    public void setTimeEntry(TimeEntry timeEntry) {
        this.timeEntry = timeEntry;
    }

    public Instant getRequestedAt() {
        return requestedAt;
    }

    public void setRequestedAt(Instant requestedAt) {
        this.requestedAt = requestedAt;
    }

    public Instant getClockInRecordedAt() {
        return clockInRecordedAt;
    }

    public void setClockInRecordedAt(Instant clockInRecordedAt) {
        this.clockInRecordedAt = clockInRecordedAt;
    }

    public Instant getLocationRequestedAt() {
        return locationRequestedAt;
    }

    public void setLocationRequestedAt(Instant locationRequestedAt) {
        this.locationRequestedAt = locationRequestedAt;
    }

    public Instant getCompletedAt() {
        return completedAt;
    }

    public void setCompletedAt(Instant completedAt) {
        this.completedAt = completedAt;
    }

    public Instant getLastInboundAt() {
        return lastInboundAt;
    }

    public void setLastInboundAt(Instant lastInboundAt) {
        this.lastInboundAt = lastInboundAt;
    }

    public String getRawClockInText() {
        return rawClockInText;
    }

    public void setRawClockInText(String rawClockInText) {
        this.rawClockInText = rawClockInText;
    }
}
