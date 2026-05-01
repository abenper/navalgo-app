package com.navalgo.backend.workorder;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;

public interface MaterialProductRepository extends JpaRepository<MaterialProduct, Long> {
    Optional<MaterialProduct> findFirstByReferenceIgnoreCase(String reference);
}
