package com.navalgo.backend.workorder;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface WorkOrderChecklistItemRepository extends JpaRepository<WorkOrderChecklistItem, Long> {

    @Modifying
    @Query("UPDATE WorkOrderChecklistItem item SET item.checkedByWorker = null WHERE item.checkedByWorker.id = :workerId")
    void clearCheckedByWorker(@Param("workerId") Long workerId);
}
