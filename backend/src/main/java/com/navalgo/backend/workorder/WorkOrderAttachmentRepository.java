package com.navalgo.backend.workorder;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface WorkOrderAttachmentRepository extends JpaRepository<WorkOrderAttachment, Long> {

    @Modifying
    @Query("UPDATE WorkOrderAttachment attachment SET attachment.uploadedByWorker = null WHERE attachment.uploadedByWorker.id = :workerId")
    void clearUploadedByWorker(@Param("workerId") Long workerId);
}
