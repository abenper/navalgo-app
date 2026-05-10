package com.navalgo.backend.budget;

import com.navalgo.backend.fleet.Owner;
import com.navalgo.backend.fleet.Vessel;

final class BudgetTarget {

    private final Owner owner;
    private final Vessel vessel;
    private final String contactName;
    private final String contactEmail;

    BudgetTarget(Owner owner, Vessel vessel, String contactName, String contactEmail) {
        this.owner = owner;
        this.vessel = vessel;
        this.contactName = contactName;
        this.contactEmail = contactEmail;
    }

    Owner owner() {
        return owner;
    }

    Vessel vessel() {
        return vessel;
    }

    String contactName() {
        return contactName;
    }

    String contactEmail() {
        return contactEmail;
    }
}
