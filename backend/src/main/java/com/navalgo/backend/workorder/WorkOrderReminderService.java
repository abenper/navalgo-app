package com.navalgo.backend.workorder;

import com.navalgo.backend.notification.NotificationService;
import com.navalgo.backend.notification.NotificationType;
import com.navalgo.backend.worker.Worker;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;
import java.util.ArrayList;
import java.util.List;
import java.util.Set;

@Service
public class WorkOrderReminderService {

    private static final List<WorkOrderStatus> CLOSED_STATUSES = List.of(
            WorkOrderStatus.DONE,
            WorkOrderStatus.CANCELLED
    );

    private final NotificationService notificationService;
    private final WorkOrderRepository workOrderRepository;

    public WorkOrderReminderService(NotificationService notificationService,
                                    WorkOrderRepository workOrderRepository) {
        this.notificationService = notificationService;
        this.workOrderRepository = workOrderRepository;
    }

    @Transactional
    @Scheduled(cron = "${app.scheduling.work-order-close-reminders-cron:0 0 9 * * *}")
    public void sendOverdueCloseReminders() {
        ZoneId zoneId = ZoneId.systemDefault();
        LocalDate today = LocalDate.now(zoneId);
        Instant now = Instant.now();

        List<WorkOrder> overdueWorkOrders = workOrderRepository
                .findByCloseDueDateBeforeAndStatusNotInOrderByCloseDueDateAsc(today, CLOSED_STATUSES);

        List<WorkOrder> updatedWorkOrders = new ArrayList<>();
        for (WorkOrder workOrder : overdueWorkOrders) {
            if (workOrder.getAssignedWorkers() == null || workOrder.getAssignedWorkers().isEmpty()) {
                continue;
            }
            if (alreadyRemindedToday(workOrder, today, zoneId)) {
                continue;
            }

            Set<Long> workerIds = workOrder.getAssignedWorkers().stream()
                    .map(Worker::getId)
                    .collect(java.util.stream.Collectors.toSet());
            if (workerIds.isEmpty()) {
                continue;
            }

            notificationService.notifyWorkers(
                    workerIds,
                    "Parte pendiente de cierre",
                    "El parte '" + workOrder.getTitle() + "' debía cerrarse el "
                            + formatDate(workOrder.getCloseDueDate())
                            + ". Revísalo y ciérralo si procede.",
                    "PARTES",
                    NotificationType.WARNING
            );

            workOrder.setLastCloseReminderSentAt(now);
            updatedWorkOrders.add(workOrder);
        }

        if (!updatedWorkOrders.isEmpty()) {
            workOrderRepository.saveAll(updatedWorkOrders);
        }
    }

    private boolean alreadyRemindedToday(WorkOrder workOrder, LocalDate today, ZoneId zoneId) {
        Instant lastReminder = workOrder.getLastCloseReminderSentAt();
        if (lastReminder == null) {
            return false;
        }
        return lastReminder.atZone(zoneId).toLocalDate().isEqual(today);
    }

    private String formatDate(LocalDate date) {
        String day = String.format("%02d", date.getDayOfMonth());
        String month = String.format("%02d", date.getMonthValue());
        return day + "/" + month + "/" + date.getYear();
    }
}