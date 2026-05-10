package com.navalgo.backend.fleet;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;

public interface OwnerRepository extends JpaRepository<Owner, Long> {
    List<Owner> findAllByArchivedFalseOrderByDisplayNameAsc();
    boolean existsByEmailIgnoreCaseAndArchivedFalse(String email);
    boolean existsByEmailIgnoreCaseAndIdNotAndArchivedFalse(String email, Long id);
    Optional<Owner> findByEmailIgnoreCaseAndArchivedFalse(String email);
    Optional<Owner> findByIdAndArchivedFalse(Long id);
}
