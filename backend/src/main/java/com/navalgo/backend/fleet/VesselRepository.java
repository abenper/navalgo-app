package com.navalgo.backend.fleet;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;
import java.util.List;

public interface VesselRepository extends JpaRepository<Vessel, Long> {
    List<Vessel> findAllByArchivedFalseOrderByNameAsc();
    List<Vessel> findByOwnerIdAndArchivedFalseOrderByNameAsc(Long ownerId);
    List<Vessel> findByOwnerIdAndArchivedFalse(Long ownerId);
    Optional<Vessel> findByIdAndArchivedFalse(Long id);
}
