package com.navalgo.backend.fleet;

import jakarta.persistence.*;

import java.util.Arrays;
import java.util.List;

@Entity
@Table(name = "vessels")
public class Vessel {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private String name;

    @Column(nullable = false, unique = true)
    private String registrationNumber;

    private String model;
    private Integer engineCount;

    @Column(name = "engine_labels", length = 1000)
    private String engineLabels;

    private Double lengthMeters;

    @ManyToOne(optional = false, fetch = FetchType.LAZY)
    private Owner owner;

    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }

    public String getName() { return name; }
    public void setName(String name) { this.name = name; }

    public String getRegistrationNumber() { return registrationNumber; }
    public void setRegistrationNumber(String registrationNumber) { this.registrationNumber = registrationNumber; }

    public String getModel() { return model; }
    public void setModel(String model) { this.model = model; }

    public Integer getEngineCount() { return engineCount; }
    public void setEngineCount(Integer engineCount) { this.engineCount = engineCount; }

    public List<String> getEngineLabels() {
        if (engineLabels == null || engineLabels.isBlank()) {
            return List.of();
        }
        return Arrays.stream(engineLabels.split("\\|"))
                .map(String::trim)
                .filter(label -> !label.isEmpty())
                .toList();
    }

    public void setEngineLabels(List<String> engineLabels) {
        if (engineLabels == null || engineLabels.isEmpty()) {
            this.engineLabels = null;
            return;
        }
        this.engineLabels = engineLabels.stream()
                .map(String::trim)
                .filter(label -> !label.isEmpty())
                .collect(java.util.stream.Collectors.joining("|"));
    }

    public Double getLengthMeters() { return lengthMeters; }
    public void setLengthMeters(Double lengthMeters) { this.lengthMeters = lengthMeters; }

    public Owner getOwner() { return owner; }
    public void setOwner(Owner owner) { this.owner = owner; }
}
