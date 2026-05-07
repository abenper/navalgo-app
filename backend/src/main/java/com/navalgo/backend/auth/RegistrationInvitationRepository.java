package com.navalgo.backend.auth;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Collection;
import java.util.List;
import java.util.Optional;

public interface RegistrationInvitationRepository extends JpaRepository<RegistrationInvitation, Long> {
    Optional<RegistrationInvitation> findByTokenHash(String tokenHash);
    boolean existsByWorker_Id(Long workerId);
    List<RegistrationInvitation> findByWorker_IdIn(Collection<Long> workerIds);
    void deleteByWorker_Id(Long workerId);
}
