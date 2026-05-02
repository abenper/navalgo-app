package com.navalgo.backend.timetracking;

import com.navalgo.backend.common.Role;
import com.navalgo.backend.notification.NotificationService;
import com.navalgo.backend.notification.NotificationType;
import com.navalgo.backend.worker.Worker;
import com.navalgo.backend.worker.WorkerRepository;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalTime;
import java.time.ZoneId;
import java.time.ZonedDateTime;
import java.util.ArrayList;
import java.util.List;

@Service
public class TimeTrackingReminderService {

    private static final LocalTime FORCE_CLOSE_TIME = LocalTime.of(22, 0);

    private final NotificationService notificationService;
    private final TimeEntryRepository timeEntryRepository;
    private final TimeTrackingService timeTrackingService;
    private final WorkerRepository workerRepository;

    public TimeTrackingReminderService(NotificationService notificationService,
                                      TimeEntryRepository timeEntryRepository,
                                      TimeTrackingService timeTrackingService,
                                      WorkerRepository workerRepository) {
        this.notificationService = notificationService;
        this.timeEntryRepository = timeEntryRepository;
        this.timeTrackingService = timeTrackingService;
        this.workerRepository = workerRepository;
    }

    @Transactional
    @Scheduled(cron = "${app.scheduling.time-tracking-missing-clock-in-cron:0 0 8 * * MON-FRI}")
    public void sendMissingClockInReminders() {
        ZoneId zoneId = ZoneId.systemDefault();
        LocalDate today = LocalDate.now(zoneId);
        List<Worker> workers = workerRepository.findByRoleAndActiveTrueOrderByFullNameAsc(Role.WORKER);
        List<Worker> updatedWorkers = new ArrayList<>();

        for (Worker worker : workers) {
            if (today.equals(worker.getLastMissingClockInReminderDate())) {
                continue;
            }
            if (timeTrackingService.isWorkerOnApprovedLeave(worker.getId(), today)) {
                continue;
            }

            Instant start = today.atStartOfDay(zoneId).toInstant();
            Instant end = today.plusDays(1).atStartOfDay(zoneId).toInstant();
            boolean hasClockedToday = !timeEntryRepository
                    .findByWorkerIdAndClockInGreaterThanEqualAndClockInLessThanOrderByClockInDesc(worker.getId(), start, end)
                    .isEmpty();
            if (hasClockedToday) {
                continue;
            }

            notificationService.notifyWorker(
                    worker.getId(),
                    "No has picado hoy",
                    "No has picado el dia de hoy.",
                    "FICHAJES",
                    NotificationType.WARNING
            );
            worker.setLastMissingClockInReminderDate(today);
            updatedWorkers.add(worker);
        }

        if (!updatedWorkers.isEmpty()) {
            workerRepository.saveAll(updatedWorkers);
        }
    }

    @Transactional
    @Scheduled(cron = "${app.scheduling.time-tracking-open-shift-reminder-cron:0 0 16 * * MON-FRI}")
    public void sendOpenShiftReminders() {
        ZoneId zoneId = ZoneId.systemDefault();
        LocalDate today = LocalDate.now(zoneId);
        Instant now = Instant.now();
        List<TimeEntry> entries = timeEntryRepository.findByClockOutIsNullOrderByClockInAsc();
        List<TimeEntry> updatedEntries = new ArrayList<>();

        for (TimeEntry entry : entries) {
            LocalDate workDate = entry.getClockIn().atZone(zoneId).toLocalDate();
            if (!workDate.equals(today)) {
                continue;
            }
            if (alreadyRemindedToday(entry.getCloseReminderSentAt(), today, zoneId)) {
                continue;
            }

            notificationService.notifyWorker(
                    entry.getWorker().getId(),
                    "Recuerda cerrar tu jornada",
                    "Recuerda cerrar tu jornada.",
                    "FICHAJES",
                    NotificationType.WARNING
            );
            entry.setCloseReminderSentAt(now);
            updatedEntries.add(entry);
        }

        if (!updatedEntries.isEmpty()) {
            timeEntryRepository.saveAll(updatedEntries);
        }
    }

    @Transactional
    @Scheduled(cron = "${app.scheduling.time-tracking-auto-close-cron:0 */5 * * * *}")
    public void processAutoClosures() {
        Instant now = Instant.now();
        handlePlannedAutoClosures(now);
        handleEndOfDayForceClosures(now);
    }

    private void handlePlannedAutoClosures(Instant now) {
        List<TimeEntry> entries = timeEntryRepository
                .findByClockOutIsNullAndPlannedClockOutLessThanEqualOrderByPlannedClockOutAsc(now);

        for (TimeEntry entry : entries) {
            Instant plannedClockOut = entry.getPlannedClockOut();
            if (plannedClockOut == null) {
                continue;
            }
            closeEntry(entry, plannedClockOut, now, TimeEntryAutoCloseReason.PLANNED_END_TIME);
            notificationService.notifyWorker(
                    entry.getWorker().getId(),
                    "Jornada cerrada automaticamente",
                    "Tu jornada se ha cerrado a la hora que indicaste, que pases buen dia!",
                    "FICHAJES",
                    NotificationType.SUCCESS
            );
        }
    }

    private void handleEndOfDayForceClosures(Instant now) {
        ZoneId zoneId = ZoneId.systemDefault();
        List<TimeEntry> entries = timeEntryRepository.findByClockOutIsNullOrderByClockInAsc();

        for (TimeEntry entry : entries) {
            ZonedDateTime clockInDateTime = entry.getClockIn().atZone(zoneId);
            ZonedDateTime forceCloseAt = clockInDateTime.toLocalDate()
                    .atTime(FORCE_CLOSE_TIME)
                    .atZone(zoneId);

            if (now.isBefore(forceCloseAt.toInstant())) {
                continue;
            }

            closeEntry(
                    entry,
                    forceCloseAt.toInstant(),
                    now,
                    TimeEntryAutoCloseReason.END_OF_DAY_FORCE_CLOSE
            );
            notificationService.notifyAdmins(
                    "Cierre automatico de jornada",
                    entry.getWorker().getFullName()
                            + " no cerro su jornada del dia "
                            + formatDate(clockInDateTime.toLocalDate())
                            + ". Revísala y modifícala si hace falta.",
                    "FICHAJES",
                    NotificationType.WARNING
            );
        }
    }

    private void closeEntry(TimeEntry entry,
                            Instant effectiveClockOut,
                            Instant autoClosedAt,
                            TimeEntryAutoCloseReason reason) {
        Instant normalizedClockOut = effectiveClockOut.isBefore(entry.getClockIn())
                ? entry.getClockIn()
                : effectiveClockOut;

        entry.setClockOut(normalizedClockOut);
        entry.setAutoClosedAt(autoClosedAt);
        entry.setAutoCloseReason(reason);
        timeEntryRepository.save(entry);
    }

    private boolean alreadyRemindedToday(Instant reminder, LocalDate today, ZoneId zoneId) {
        if (reminder == null) {
            return false;
        }
        return reminder.atZone(zoneId).toLocalDate().isEqual(today);
    }

    private String formatDate(LocalDate date) {
        return String.format("%02d/%02d/%04d", date.getDayOfMonth(), date.getMonthValue(), date.getYear());
    }
}
