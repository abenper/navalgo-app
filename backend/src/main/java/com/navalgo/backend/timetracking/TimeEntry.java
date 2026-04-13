package com.navalgo.backend.timetracking;

import com.navalgo.backend.worker.Worker;
import jakarta.persistence.*;

import java.time.Instant;

@Entity
@Table(name = "time_entries")
public class TimeEntry {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(optional = false, fetch = FetchType.LAZY)
    private Worker worker;

    @Column(nullable = false)
    private Instant clockIn;

    private Instant clockOut;

    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }

    public Worker getWorker() { return worker; }
    public void setWorker(Worker worker) { this.worker = worker; }

    public Instant getClockIn() { return clockIn; }
    public void setClockIn(Instant clockIn) { this.clockIn = clockIn; }

    public Instant getClockOut() { return clockOut; }
    public void setClockOut(Instant clockOut) { this.clockOut = clockOut; }
}
