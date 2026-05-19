package com.navalgo.backend.worker;

import com.navalgo.backend.common.Role;
import com.navalgo.backend.fleet.Owner;
import jakarta.persistence.*;

import java.time.LocalDate;

@Entity
@Table(name = "workers")
public class Worker {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private String fullName;

    @Column(nullable = false, unique = true)
    private String email;

    @Column(nullable = false)
    private String passwordHash;

    private String speciality;

    @Column(nullable = false)
    private String phonePrefix;

    @Column(nullable = false)
    private String phone;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private Role role = Role.WORKER;

    @Column(nullable = false)
    private boolean active = true;

    @Column(nullable = false)
    private boolean mustChangePassword = false;

    @Column(nullable = false)
    private boolean canEditWorkOrders = false;

    @Column(nullable = false)
    private boolean emailVerified = true;

    @Column(nullable = false)
    private LocalDate contractStartDate = LocalDate.now();

    @Column(length = 1000)
    private String photoUrl;

    @OneToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "owner_id", unique = true)
    private Owner owner;

    private LocalDate lastMissingClockInReminderDate;

    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }

    public String getFullName() { return fullName; }
    public void setFullName(String fullName) { this.fullName = fullName; }

    public String getEmail() { return email; }
    public void setEmail(String email) { this.email = email; }

    public String getPasswordHash() { return passwordHash; }
    public void setPasswordHash(String passwordHash) { this.passwordHash = passwordHash; }

    public String getSpeciality() { return speciality; }
    public void setSpeciality(String speciality) { this.speciality = speciality; }

    public String getPhonePrefix() { return phonePrefix; }
    public void setPhonePrefix(String phonePrefix) { this.phonePrefix = phonePrefix; }

    public String getPhone() { return phone; }
    public void setPhone(String phone) { this.phone = phone; }

    public Role getRole() { return role; }
    public void setRole(Role role) { this.role = role; }

    public boolean isActive() { return active; }
    public void setActive(boolean active) { this.active = active; }

    public boolean isMustChangePassword() { return mustChangePassword; }
    public void setMustChangePassword(boolean mustChangePassword) { this.mustChangePassword = mustChangePassword; }

    public boolean isCanEditWorkOrders() { return canEditWorkOrders; }
    public void setCanEditWorkOrders(boolean canEditWorkOrders) { this.canEditWorkOrders = canEditWorkOrders; }

    public boolean isEmailVerified() { return emailVerified; }
    public void setEmailVerified(boolean emailVerified) { this.emailVerified = emailVerified; }

    public LocalDate getContractStartDate() { return contractStartDate; }
    public void setContractStartDate(LocalDate contractStartDate) { this.contractStartDate = contractStartDate; }

    public String getPhotoUrl() { return photoUrl; }
    public void setPhotoUrl(String photoUrl) { this.photoUrl = photoUrl; }

    public Owner getOwner() { return owner; }
    public void setOwner(Owner owner) { this.owner = owner; }

    public LocalDate getLastMissingClockInReminderDate() { return lastMissingClockInReminderDate; }
    public void setLastMissingClockInReminderDate(LocalDate lastMissingClockInReminderDate) {
        this.lastMissingClockInReminderDate = lastMissingClockInReminderDate;
    }
}
