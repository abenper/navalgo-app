package com.navalgo.backend.timetracking;

import com.navalgo.backend.common.Role;
import com.navalgo.backend.notification.NotificationDeliveryOptions;
import com.navalgo.backend.notification.NotificationService;
import com.navalgo.backend.notification.NotificationType;
import com.navalgo.backend.notification.ResendEmailService;
import com.navalgo.backend.notification.WhatsAppClockInFlowService;
import com.navalgo.backend.worker.Worker;
import com.navalgo.backend.worker.WorkerRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalTime;
import java.time.ZoneId;
import java.time.ZonedDateTime;
import java.util.ArrayList;
import java.util.EnumSet;
import java.util.List;

@Service
public class TimeTrackingReminderService {

    private static final Logger log = LoggerFactory.getLogger(TimeTrackingReminderService.class);
    private static final ZoneId BUSINESS_ZONE = ZoneId.of("Europe/Madrid");
    private static final LocalTime FORCE_CLOSE_DEADLINE = LocalTime.of(23, 59);
    private static final LocalTime FORCE_CLOSE_RECORDED_CLOCK_OUT = LocalTime.of(15, 0);

    private final NotificationService notificationService;
    private final TimeEntryRepository timeEntryRepository;
    private final TimeTrackingService timeTrackingService;
    private final WorkerRepository workerRepository;
    private final ResendEmailService resendEmailService;
    private final WhatsAppClockInFlowService whatsAppClockInFlowService;

    public TimeTrackingReminderService(NotificationService notificationService,
                                       TimeEntryRepository timeEntryRepository,
                                       TimeTrackingService timeTrackingService,
                                       WorkerRepository workerRepository,
                                       ResendEmailService resendEmailService,
                                       WhatsAppClockInFlowService whatsAppClockInFlowService) {
        this.notificationService = notificationService;
        this.timeEntryRepository = timeEntryRepository;
        this.timeTrackingService = timeTrackingService;
        this.workerRepository = workerRepository;
        this.resendEmailService = resendEmailService;
        this.whatsAppClockInFlowService = whatsAppClockInFlowService;
    }

    @Transactional
    @Scheduled(cron = "${app.scheduling.time-tracking-missing-clock-in-cron:0 0 8 * * MON-FRI}")
    public void sendMissingClockInReminders() {
        ZoneId zoneId = BUSINESS_ZONE;
        LocalDate today = LocalDate.now(zoneId);
        List<Worker> workers = workerRepository.findByRoleInAndActiveTrueOrderByFullNameAsc(
                EnumSet.of(Role.WORKER, Role.COMERCIAL)
        );
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
                    "No has fichado hoy",
                    "No has fichado en el dia de hoy.",
                    "FICHAJES",
                    NotificationType.WARNING,
                    NotificationDeliveryOptions.DEFAULT
            );
            sendDirectReminderEmail(worker, "No has fichado hoy", "No has fichado en el dia de hoy.");
            sendWhatsAppReminder(worker, today);
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
        ZoneId zoneId = BUSINESS_ZONE;
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
                    NotificationType.WARNING,
                    NotificationDeliveryOptions.EMAIL_FALLBACK
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
                    "Tu jornada se ha cerrado a la hora que indicaste. Que pases buen dia.",
                    "FICHAJES",
                    NotificationType.SUCCESS,
                    NotificationDeliveryOptions.EMAIL_FALLBACK
            );
        }
    }

    private void handleEndOfDayForceClosures(Instant now) {
        ZoneId zoneId = BUSINESS_ZONE;
        List<TimeEntry> entries = timeEntryRepository.findByClockOutIsNullOrderByClockInAsc();

        for (TimeEntry entry : entries) {
            ZonedDateTime clockInDateTime = entry.getClockIn().atZone(zoneId);
            ZonedDateTime forceCloseAt = clockInDateTime.toLocalDate()
                    .atTime(FORCE_CLOSE_DEADLINE)
                    .atZone(zoneId);
            ZonedDateTime recordedClockOut = clockInDateTime.toLocalDate()
                    .atTime(FORCE_CLOSE_RECORDED_CLOCK_OUT)
                    .atZone(zoneId);

            if (now.isBefore(forceCloseAt.toInstant())) {
                continue;
            }

            closeEntry(
                    entry,
                    recordedClockOut.toInstant(),
                    now,
                    TimeEntryAutoCloseReason.END_OF_DAY_FORCE_CLOSE
            );
            notificationService.notifyAdmins(
                    "Cierre automatico de jornada",
                    entry.getWorker().getFullName()
                            + " no cerro su jornada del dia "
                            + formatDate(clockInDateTime.toLocalDate())
                            + ". Revisala y modificala si hace falta.",
                    "FICHAJES",
                    NotificationType.WARNING,
                    NotificationDeliveryOptions.EMAIL_FALLBACK
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

    private void sendDirectReminderEmail(Worker worker, String title, String message) {
        try {
            resendEmailService.sendNotificationFallback(
                    worker.getFullName(),
                    worker.getEmail(),
                    title,
                    message
            );
        } catch (RuntimeException exception) {
            log.warn("No se pudo enviar el email directo de recordatorio de fichaje. workerId={}", worker.getId(), exception);
        }
    }

    private void sendWhatsAppReminder(Worker worker, LocalDate today) {
        try {
            whatsAppClockInFlowService.sendMissingClockInReminder(worker, today);
        } catch (RuntimeException exception) {
            log.warn("No se pudo enviar el recordatorio de WhatsApp. workerId={}", worker.getId(), exception);
        }
    }
}
