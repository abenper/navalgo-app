package com.navalgo.backend.notification;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Collection;
import java.util.List;
import java.util.Optional;

public interface WorkerPushTokenRepository extends JpaRepository<WorkerPushToken, Long> {
    Optional<WorkerPushToken> findByToken(String token);
    List<WorkerPushToken> findByWorkerIdAndActiveTrue(Long workerId);
    List<WorkerPushToken> findByActiveTrueOrderByLastSeenAtDesc();
    List<WorkerPushToken> findByTokenIn(Collection<String> tokens);
}
