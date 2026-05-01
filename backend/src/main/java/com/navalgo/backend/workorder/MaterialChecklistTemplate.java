package com.navalgo.backend.workorder;

import jakarta.persistence.*;

import java.time.Instant;
import java.util.LinkedHashSet;
import java.util.Set;

@Entity
@Table(name = "material_checklist_templates")
public class MaterialChecklistTemplate {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, length = 255)
    private String name;

    @Column(length = 1000)
    private String description;

    @Enumerated(EnumType.STRING)
    @Column(name = "template_type", nullable = false, length = 20)
    private MaterialChecklistTemplateType templateType = MaterialChecklistTemplateType.BASIC;

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "base_template_id")
    private MaterialChecklistTemplate baseTemplate;

    @OneToMany(mappedBy = "template", cascade = CascadeType.ALL, orphanRemoval = true)
    @OrderBy("sortOrder ASC, id ASC")
    private Set<MaterialChecklistTemplateItem> items = new LinkedHashSet<>();

    @Column(nullable = false)
    private Instant createdAt = Instant.now();

    @Column(nullable = false)
    private Instant updatedAt = Instant.now();

    @PreUpdate
    void onUpdate() {
        updatedAt = Instant.now();
    }

    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }

    public String getName() { return name; }
    public void setName(String name) { this.name = name; }

    public String getDescription() { return description; }
    public void setDescription(String description) { this.description = description; }

    public MaterialChecklistTemplateType getTemplateType() { return templateType; }
    public void setTemplateType(MaterialChecklistTemplateType templateType) { this.templateType = templateType; }

    public MaterialChecklistTemplate getBaseTemplate() { return baseTemplate; }
    public void setBaseTemplate(MaterialChecklistTemplate baseTemplate) { this.baseTemplate = baseTemplate; }

    public Set<MaterialChecklistTemplateItem> getItems() { return items; }
    public void setItems(Set<MaterialChecklistTemplateItem> items) { this.items = items; }

    public Instant getCreatedAt() { return createdAt; }
    public void setCreatedAt(Instant createdAt) { this.createdAt = createdAt; }

    public Instant getUpdatedAt() { return updatedAt; }
    public void setUpdatedAt(Instant updatedAt) { this.updatedAt = updatedAt; }
}
