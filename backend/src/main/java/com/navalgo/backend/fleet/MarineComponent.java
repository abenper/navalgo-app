package com.navalgo.backend.fleet;

import com.navalgo.backend.workorder.MaterialChecklistTemplate;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.JoinTable;
import jakarta.persistence.ManyToMany;
import jakarta.persistence.OrderBy;
import jakarta.persistence.Table;

import java.util.LinkedHashSet;
import java.util.Set;

@Entity
@Table(name = "marine_components")
public class MarineComponent {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 30)
    private VesselComponentType type = VesselComponentType.ENGINE;

    @Column(nullable = false, length = 255)
    private String name;

    @Column(length = 255)
    private String manufacturer;

    @Column(length = 255)
    private String model;

    @Column(nullable = false)
    private boolean archived = false;

    @ManyToMany
    @JoinTable(
            name = "marine_component_templates",
            joinColumns = @JoinColumn(name = "component_id"),
            inverseJoinColumns = @JoinColumn(name = "template_id")
    )
    @OrderBy("name ASC")
    private Set<MaterialChecklistTemplate> templates = new LinkedHashSet<>();

    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }

    public VesselComponentType getType() { return type; }
    public void setType(VesselComponentType type) { this.type = type; }

    public String getName() { return name; }
    public void setName(String name) { this.name = name; }

    public String getManufacturer() { return manufacturer; }
    public void setManufacturer(String manufacturer) { this.manufacturer = manufacturer; }

    public String getModel() { return model; }
    public void setModel(String model) { this.model = model; }

    public boolean isArchived() { return archived; }
    public void setArchived(boolean archived) { this.archived = archived; }

    public Set<MaterialChecklistTemplate> getTemplates() { return templates; }
    public void setTemplates(Set<MaterialChecklistTemplate> templates) { this.templates = templates; }
}
