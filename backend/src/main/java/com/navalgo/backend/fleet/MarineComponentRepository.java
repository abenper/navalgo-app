package com.navalgo.backend.fleet;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface MarineComponentRepository extends JpaRepository<MarineComponent, Long> {
    List<MarineComponent> findAllByArchivedFalseOrderByTypeAscManufacturerAscModelAscNameAsc();
}
