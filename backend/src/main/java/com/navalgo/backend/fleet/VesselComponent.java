package com.navalgo.backend.fleet;

import com.navalgo.backend.workorder.MaterialChecklistTemplate;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.FetchType;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.JoinTable;
import jakarta.persistence.ManyToMany;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.OrderBy;
import jakarta.persistence.Table;

import java.util.LinkedHashSet;
import java.util.Set;

@Entity
@Table(name = "vessel_components")
public class VesselComponent {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(optional = false, fetch = FetchType.LAZY)
    private Vessel vessel;

    @ManyToOne(fetch = FetchType.LAZY)
    private MarineComponent marineComponent;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 30)
    private VesselComponentType type = VesselComponentType.ENGINE;

    @Column(nullable = false, length = 255)
    private String label;

    @Column(length = 255)
    private String manufacturer;

    @Column(length = 255)
    private String model;

    @Column(length = 255)
    private String serialNumber;

    private Integer currentHours;

    @ManyToMany
    @JoinTable(
            name = "vessel_component_templates",
            joinColumns = @JoinColumn(name = "component_id"),
            inverseJoinColumns = @JoinColumn(name = "template_id")
    )
    @OrderBy("name ASC")
    private Set<MaterialChecklistTemplate> templates = new LinkedHashSet<>();

    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }

    public Vessel getVessel() { return vessel; }
    public void setVessel(Vessel vessel) { this.vessel = vessel; }

    public MarineComponent getMarineComponent() { return marineComponent; }
    public void setMarineComponent(MarineComponent marineComponent) { this.marineComponent = marineComponent; }

    public VesselComponentType getType() { return type; }
    public void setType(VesselComponentType type) { this.type = type; }

    public String getLabel() { return label; }
    public void setLabel(String label) { this.label = label; }

    public String getManufacturer() { return manufacturer; }
    public void setManufacturer(String manufacturer) { this.manufacturer = manufacturer; }

    public String getModel() { return model; }
    public void setModel(String model) { this.model = model; }

    public String getSerialNumber() { return serialNumber; }
    public void setSerialNumber(String serialNumber) { this.serialNumber = serialNumber; }

    public Integer getCurrentHours() { return currentHours; }
    public void setCurrentHours(Integer currentHours) { this.currentHours = currentHours; }

    public Set<MaterialChecklistTemplate> getTemplates() { return templates; }
    public void setTemplates(Set<MaterialChecklistTemplate> templates) { this.templates = templates; }
}
