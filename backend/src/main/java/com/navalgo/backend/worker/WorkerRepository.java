package com.navalgo.backend.worker;

import com.navalgo.backend.common.Role;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;

public interface WorkerRepository extends JpaRepository<Worker, Long> {
    Optional<Worker> findByEmailIgnoreCase(String email);
    List<Worker> findByRoleAndActiveTrue(Role role);
}
