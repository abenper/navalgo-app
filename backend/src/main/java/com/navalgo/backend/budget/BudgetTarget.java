package com.navalgo.backend.budget;

import com.navalgo.backend.fleet.Owner;
import com.navalgo.backend.fleet.Vessel;

final class BudgetTarget {

    private final Owner owner;
    private final Vessel vessel;

    BudgetTarget(Owner owner, Vessel vessel) {
        this.owner = owner;
        this.vessel = vessel;
    }

    Owner owner() {
        return owner;
    }

    Vessel vessel() {
        return vessel;
    }
}
