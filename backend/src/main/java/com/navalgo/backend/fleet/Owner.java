package com.navalgo.backend.fleet;

import com.navalgo.backend.company.Company;
import jakarta.persistence.*;

@Entity
@Table(name = "owners")
public class Owner {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private OwnerType type;

    @Column(nullable = false)
    private String displayName;

    @Column(nullable = false)
    private String documentId;

    private String phone;
    private String email;

    @ManyToOne(fetch = FetchType.LAZY)
    private Company company;

    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }

    public OwnerType getType() { return type; }
    public void setType(OwnerType type) { this.type = type; }

    public String getDisplayName() { return displayName; }
    public void setDisplayName(String displayName) { this.displayName = displayName; }

    public String getDocumentId() { return documentId; }
    public void setDocumentId(String documentId) { this.documentId = documentId; }

    public String getPhone() { return phone; }
    public void setPhone(String phone) { this.phone = phone; }

    public String getEmail() { return email; }
    public void setEmail(String email) { this.email = email; }

    public Company getCompany() { return company; }
    public void setCompany(Company company) { this.company = company; }
}
