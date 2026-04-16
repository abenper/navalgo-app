package com.navalgo.backend.workorder;

import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;
import java.util.Optional;

public interface WorkOrderRepository extends JpaRepository<WorkOrder, Long> {
    List<WorkOrder> findByStatus(WorkOrderStatus status);
    List<WorkOrder> findByAssignedWorkersId(Long workerId);

    @EntityGraph(attributePaths = {
        "owner",
        "vessel",
        "assignedWorkers",
        "engineHourLogs",
        "attachments",
        "signedByWorker"
    })
    @Query("""
        select distinct w
        from WorkOrder w
        left join w.assignedWorkers aw
        order by w.createdAt desc
        """)
    List<WorkOrder> findAllWithRelationsOrderByCreatedAtDesc();

    @EntityGraph(attributePaths = {
        "owner",
        "vessel",
        "assignedWorkers",
        "engineHourLogs",
        "attachments",
        "signedByWorker"
    })
    @Query("""
        select distinct w
        from WorkOrder w
        left join w.assignedWorkers aw
        where aw.id = :workerId
        order by w.createdAt desc
        """)
    List<WorkOrder> findByWorkerWithRelationsOrderByCreatedAtDesc(@Param("workerId") Long workerId);

    @EntityGraph(attributePaths = {
        "owner",
        "vessel",
        "assignedWorkers",
        "engineHourLogs",
        "attachments",
        "signedByWorker"
    })
    @Query("""
        select w
        from WorkOrder w
        where w.id = :id
        """)
    Optional<WorkOrder> findByIdWithRelations(@Param("id") Long id);
}
