package com.navalgo.backend.workorder;

import jakarta.persistence.*;

@Entity
@Table(name = "material_checklist_template_items")
public class MaterialChecklistTemplateItem {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "template_id", nullable = false)
    private MaterialChecklistTemplate template;

    @ManyToOne(fetch = FetchType.LAZY, optional = false)
    @JoinColumn(name = "product_id", nullable = false)
    private MaterialProduct product;

    @Column(nullable = false, length = 255)
    private String articleName;

    @Column(name = "reference_code", nullable = false, length = 255)
    private String reference;

    @Column(nullable = false)
    private int sortOrder;

    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }

    public MaterialChecklistTemplate getTemplate() { return template; }
    public void setTemplate(MaterialChecklistTemplate template) { this.template = template; }

    public MaterialProduct getProduct() { return product; }
    public void setProduct(MaterialProduct product) { this.product = product; }

    public String getArticleName() { return articleName; }
    public void setArticleName(String articleName) { this.articleName = articleName; }

    public String getReference() { return reference; }
    public void setReference(String reference) { this.reference = reference; }

    public int getSortOrder() { return sortOrder; }
    public void setSortOrder(int sortOrder) { this.sortOrder = sortOrder; }
}
