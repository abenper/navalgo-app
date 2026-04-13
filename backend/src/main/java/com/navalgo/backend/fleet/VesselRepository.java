package com.navalgo.backend.fleet;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface VesselRepository extends JpaRepository<Vessel, Long> {
    List<Vessel> findByOwnerId(Long ownerId);
}
