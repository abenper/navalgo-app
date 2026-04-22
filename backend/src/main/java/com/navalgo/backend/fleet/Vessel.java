package com.navalgo.backend.fleet;

import jakarta.persistence.*;

import java.util.Arrays;
import java.util.List;
import java.util.stream.Collectors;

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

    @Column(name = "engine_serial_numbers", length = 1000)
    private String engineSerialNumbers;

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

    public List<String> getEngineSerialNumbers() {
        if (engineSerialNumbers == null || engineSerialNumbers.isBlank()) {
            return List.of();
        }

        String[] rawValues = engineSerialNumbers.contains("|")
                ? engineSerialNumbers.split("\\|", -1)
                : engineSerialNumbers.split("\\s*,\\s*", -1);

        int lastNonBlankIndex = rawValues.length - 1;
        while (lastNonBlankIndex >= 0 && rawValues[lastNonBlankIndex].trim().isEmpty()) {
            lastNonBlankIndex--;
        }

        if (lastNonBlankIndex < 0) {
            return List.of();
        }

        return Arrays.stream(rawValues, 0, lastNonBlankIndex + 1)
                .map(value -> value == null ? "" : value.trim())
                .toList();
    }

    public void setEngineSerialNumbers(List<String> engineSerialNumbers) {
        if (engineSerialNumbers == null || engineSerialNumbers.isEmpty()) {
            this.engineSerialNumbers = null;
            return;
        }

        List<String> normalized = engineSerialNumbers.stream()
                .map(value -> value == null ? "" : value.trim())
                .toList();

        int lastNonBlankIndex = normalized.size() - 1;
        while (lastNonBlankIndex >= 0 && normalized.get(lastNonBlankIndex).isEmpty()) {
            lastNonBlankIndex--;
        }

        if (lastNonBlankIndex < 0) {
            this.engineSerialNumbers = null;
            return;
        }

        this.engineSerialNumbers = normalized.subList(0, lastNonBlankIndex + 1).stream()
                .collect(Collectors.joining("|"));
    }

    public Double getLengthMeters() { return lengthMeters; }
    public void setLengthMeters(Double lengthMeters) { this.lengthMeters = lengthMeters; }

    public Owner getOwner() { return owner; }
    public void setOwner(Owner owner) { this.owner = owner; }
}
