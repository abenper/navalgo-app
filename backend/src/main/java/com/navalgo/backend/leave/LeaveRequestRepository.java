package com.navalgo.backend.leave;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

public interface LeaveRequestRepository extends JpaRepository<LeaveRequestEntity, Long> {
    List<LeaveRequestEntity> findByWorkerIdOrderByStartDateDesc(Long workerId);
}
