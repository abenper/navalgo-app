package com.navalgo.backend.auth;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;

public interface RegistrationInvitationRepository extends JpaRepository<RegistrationInvitation, Long> {
    Optional<RegistrationInvitation> findByTokenHash(String tokenHash);
    void deleteByWorker_Id(Long workerId);
}
