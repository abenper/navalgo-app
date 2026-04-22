package com.navalgo.backend.workorder;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;

public interface WorkOrderRepository extends JpaRepository<WorkOrder, Long> {
    List<WorkOrder> findByStatus(WorkOrderStatus status);
    List<WorkOrder> findByAssignedWorkersId(Long workerId);

    List<WorkOrder> findAllByOrderByCreatedAtDesc();
    List<WorkOrder> findByAssignedWorkersIdOrderByCreatedAtDesc(Long workerId);
    boolean existsByVesselId(Long vesselId);
    List<WorkOrder> findByVesselIdOrderByCreatedAtDesc(Long vesselId);

    @Modifying
    @Query(value = "DELETE FROM work_order_workers WHERE worker_id = :workerId", nativeQuery = true)
    void removeWorkerFromAllWorkOrders(@Param("workerId") Long workerId);

    @Modifying
    @Query("UPDATE WorkOrder wo SET wo.signedByWorker = null WHERE wo.signedByWorker.id = :workerId")
    void clearSignedByWorker(@Param("workerId") Long workerId);
}
