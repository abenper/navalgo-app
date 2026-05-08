package com.navalgo.backend.worker;

import com.navalgo.backend.common.Role;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.Collection;
import java.util.List;
import java.util.Optional;
import java.util.Set;

public interface WorkerRepository extends JpaRepository<Worker, Long> {
    Optional<Worker> findByEmailIgnoreCase(String email);
    Optional<Worker> findByOwner_Id(Long ownerId);
    List<Worker> findByRoleAndActiveTrue(Role role);
    List<Worker> findByRoleAndActiveTrueOrderByFullNameAsc(Role role);
    boolean existsByRoleAndOwner_Id(Role role, Long ownerId);

    @Query("select w.owner.id from Worker w where w.role = :role and w.owner.id in :ownerIds")
    Set<Long> findOwnerIdsByRoleAndOwnerIdIn(@Param("role") Role role, @Param("ownerIds") Collection<Long> ownerIds);
}
