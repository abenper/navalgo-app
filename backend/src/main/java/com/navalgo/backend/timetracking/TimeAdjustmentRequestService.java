package com.navalgo.backend.timetracking;

import com.navalgo.backend.common.Role;
import com.navalgo.backend.leave.LeaveRequestRepository;
import com.navalgo.backend.leave.LeaveStatus;
import com.navalgo.backend.notification.NotificationService;
import com.navalgo.backend.notification.NotificationType;
import com.navalgo.backend.notification.NotificationDeliveryOptions;
import com.navalgo.backend.worker.Worker;
import com.navalgo.backend.worker.WorkerRepository;
import jakarta.persistence.EntityNotFoundException;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.time.DayOfWeek;
import java.time.LocalDate;
import java.time.LocalTime;
import java.time.ZoneId;
import java.util.List;
import java.util.Set;
import java.time.temporal.ChronoUnit;

@Service
@Transactional(readOnly = true)
public class TimeAdjustmentRequestService {

    private static final ZoneId BUSINESS_ZONE = ZoneId.of("Europe/Madrid");
    private static final LocalTime AUTO_APPROVE_CLOCK_IN = LocalTime.of(8, 0);
    private static final LocalTime AUTO_APPROVE_CLOCK_OUT = LocalTime.of(15, 0);

    private final NotificationService notificationService;
    private final LeaveRequestRepository leaveRequestRepository;
    private final TimeAdjustmentRequestRepository timeAdjustmentRequestRepository;
    private final TimeEntryRepository timeEntryRepository;
    private final WorkerRepository workerRepository;

    public TimeAdjustmentRequestService(NotificationService notificationService,
                                        LeaveRequestRepository leaveRequestRepository,
                                        TimeAdjustmentRequestRepository timeAdjustmentRequestRepository,
                                        TimeEntryRepository timeEntryRepository,
                                        WorkerRepository workerRepository) {
        this.notificationService = notificationService;
        this.leaveRequestRepository = leaveRequestRepository;
        this.timeAdjustmentRequestRepository = timeAdjustmentRequestRepository;
        this.timeEntryRepository = timeEntryRepository;
        this.workerRepository = workerRepository;
    }

    public List<TimeAdjustmentRequestDto> listForUser(Long currentWorkerId,
                                                      boolean admin,
                                                      TimeAdjustmentRequestStatus status) {
        List<TimeAdjustmentRequest> requests;
        if (admin) {
            requests = status == null
                    ? timeAdjustmentRequestRepository.findAllByOrderByCreatedAtDesc()
                    : timeAdjustmentRequestRepository.findByStatusOrderByCreatedAtDesc(status);
        } else {
            requests = timeAdjustmentRequestRepository.findByWorkerIdOrderByCreatedAtDesc(currentWorkerId);
        }

        return requests.stream()
                .map(TimeAdjustmentRequestDto::from)
                .toList();
    }

    @Transactional
    public TimeAdjustmentRequestDto create(Long currentWorkerId, CreateTimeAdjustmentRequest request) {
        Worker worker = workerRepository.findById(currentWorkerId)
                .orElseThrow(() -> new EntityNotFoundException("Trabajador no encontrado"));
        return createInternal(worker, currentWorkerId, request);
    }

    @Transactional
    public TimeAdjustmentRequestDto createFromWhatsApp(Long workerId,
                                                       LocalDate workDate,
                                                       Instant requestedClockIn,
                                                       TimeEntryWorkSite workSite,
                                                       String reason) {
        Worker worker = workerRepository.findById(workerId)
                .orElseThrow(() -> new EntityNotFoundException("Trabajador no encontrado"));
        CreateTimeAdjustmentRequest request = new CreateTimeAdjustmentRequest(
                resolveLinkedTimeEntryId(workerId, workDate),
                workDate,
                requestedClockIn,
                null,
                workSite == null ? TimeEntryWorkSite.WORKSHOP : workSite,
                reason
        );
        return createInternal(worker, workerId, request);
    }

    private TimeAdjustmentRequestDto createInternal(Worker worker,
                                                    Long currentWorkerId,
                                                    CreateTimeAdjustmentRequest request) {
        TimeAdjustmentRequest entity = new TimeAdjustmentRequest();
        entity.setWorker(worker);
        applyEditableFields(entity, currentWorkerId, request);
        entity.setStatus(TimeAdjustmentRequestStatus.PENDING);
        entity.setCreatedAt(Instant.now());

        if (canAutoApproveStandardWorkday(entity)) {
            applyAdjustment(entity);
            entity.setStatus(TimeAdjustmentRequestStatus.APPROVED);
            entity.setAdminComment("Autoaprobado: jornada estándar 08:00-15:00 sin ausencias registradas.");
            entity.setReviewedAt(Instant.now());
            TimeAdjustmentRequest saved = timeAdjustmentRequestRepository.save(entity);
            notificationService.notifyWorker(
                    worker.getId(),
                    "Ajuste de fichaje autoaprobado",
                    "Tu solicitud de ajuste del " + formatDate(saved.getWorkDate()) + " se ha aplicado automáticamente.",
                    "FICHAJES",
                    NotificationType.SUCCESS,
                    NotificationDeliveryOptions.EMAIL_FALLBACK
            );
            return TimeAdjustmentRequestDto.from(saved);
        }

        TimeAdjustmentRequest saved = timeAdjustmentRequestRepository.save(entity);
        notificationService.notifyAdmins(
                "Solicitud de ajuste de fichaje",
                worker.getFullName() + " ha solicitado revisar el fichaje del " + formatDate(request.workDate()) + ".",
                "FICHAJES",
                NotificationType.WARNING,
                NotificationDeliveryOptions.EMAIL_FALLBACK
        );
        return TimeAdjustmentRequestDto.from(saved);
    }

    @Transactional
    public TimeAdjustmentRequestDto update(Long requestId,
                                           Long currentWorkerId,
                                           CreateTimeAdjustmentRequest request) {
        TimeAdjustmentRequest entity = timeAdjustmentRequestRepository.findById(requestId)
                .orElseThrow(() -> new EntityNotFoundException("Solicitud de ajuste no encontrada"));

        if (!entity.getWorker().getId().equals(currentWorkerId)) {
            throw new AccessDeniedException("Solo puedes editar tus propias solicitudes");
        }
        if (entity.getStatus() != TimeAdjustmentRequestStatus.PENDING) {
            throw new IllegalArgumentException("Solo puedes editar solicitudes pendientes");
        }

        applyEditableFields(entity, currentWorkerId, request);
        entity.setAdminComment(null);
        entity.setReviewedAt(null);
        entity.setReviewedByWorker(null);

        if (canAutoApproveStandardWorkday(entity)) {
            applyAdjustment(entity);
            entity.setStatus(TimeAdjustmentRequestStatus.APPROVED);
            entity.setAdminComment("Autoaprobado: jornada estándar 08:00-15:00 sin ausencias registradas.");
            entity.setReviewedAt(Instant.now());
            TimeAdjustmentRequest saved = timeAdjustmentRequestRepository.save(entity);
            notificationService.notifyWorker(
                    saved.getWorker().getId(),
                    "Ajuste de fichaje autoaprobado",
                    "Tu solicitud de ajuste del " + formatDate(saved.getWorkDate()) + " se ha aplicado automáticamente.",
                    "FICHAJES",
                    NotificationType.SUCCESS,
                    NotificationDeliveryOptions.EMAIL_FALLBACK
            );
            return TimeAdjustmentRequestDto.from(saved);
        }

        TimeAdjustmentRequest saved = timeAdjustmentRequestRepository.save(entity);
        notificationService.notifyAdmins(
                "Solicitud de ajuste modificada",
                entity.getWorker().getFullName() + " ha modificado un ajuste de fichaje del " + formatDate(saved.getWorkDate()) + ".",
                "FICHAJES",
                NotificationType.INFO
        );
        return TimeAdjustmentRequestDto.from(saved);
    }

    private boolean canAutoApproveStandardWorkday(TimeAdjustmentRequest request) {
        if (request.getRequestedClockIn() == null || request.getRequestedClockOut() == null) {
            return false;
        }

        LocalDate workDate = request.getWorkDate();
        if (workDate == null || isWeekend(workDate)) {
            return false;
        }

        LocalDate clockInDate = request.getRequestedClockIn().atZone(BUSINESS_ZONE).toLocalDate();
        LocalDate clockOutDate = request.getRequestedClockOut().atZone(BUSINESS_ZONE).toLocalDate();
        if (!workDate.equals(clockInDate) || !workDate.equals(clockOutDate)) {
            return false;
        }

        LocalTime clockIn = request.getRequestedClockIn().atZone(BUSINESS_ZONE).toLocalTime().truncatedTo(ChronoUnit.MINUTES);
        LocalTime clockOut = request.getRequestedClockOut().atZone(BUSINESS_ZONE).toLocalTime().truncatedTo(ChronoUnit.MINUTES);
        if (!AUTO_APPROVE_CLOCK_IN.equals(clockIn) || !AUTO_APPROVE_CLOCK_OUT.equals(clockOut)) {
            return false;
        }

        if (hasActiveLeaveOnDate(request.getWorker().getId(), workDate)) {
            return false;
        }

        return request.getTimeEntry() != null || !hasExistingEntriesOnDate(request.getWorker().getId(), workDate);
    }

    private boolean isWeekend(LocalDate workDate) {
        DayOfWeek day = workDate.getDayOfWeek();
        return day == DayOfWeek.SATURDAY || day == DayOfWeek.SUNDAY;
    }

    private boolean hasActiveLeaveOnDate(Long workerId, LocalDate workDate) {
        return leaveRequestRepository.existsByWorkerIdAndStatusInAndStartDateLessThanEqualAndEndDateGreaterThanEqual(
                workerId,
                Set.of(LeaveStatus.PENDING, LeaveStatus.APPROVED),
                workDate,
                workDate
        );
    }

    private boolean hasExistingEntriesOnDate(Long workerId, LocalDate workDate) {
        Instant start = workDate.atStartOfDay(BUSINESS_ZONE).toInstant();
        Instant end = workDate.plusDays(1).atStartOfDay(BUSINESS_ZONE).toInstant();
        return !timeEntryRepository
                .findByWorkerIdAndClockInGreaterThanEqualAndClockInLessThanOrderByClockInDesc(workerId, start, end)
                .isEmpty();
    }

    @Transactional
    public void delete(Long requestId, Long currentWorkerId, boolean admin) {
        TimeAdjustmentRequest entity = timeAdjustmentRequestRepository.findById(requestId)
                .orElseThrow(() -> new EntityNotFoundException("Solicitud de ajuste no encontrada"));

        if (!admin && !entity.getWorker().getId().equals(currentWorkerId)) {
            throw new AccessDeniedException("Solo puedes eliminar tus propias solicitudes");
        }
        if (!admin && entity.getStatus() != TimeAdjustmentRequestStatus.PENDING) {
            throw new IllegalArgumentException("Solo puedes eliminar solicitudes pendientes");
        }

        String workerName = entity.getWorker().getFullName();
        LocalDate workDate = entity.getWorkDate();
        timeAdjustmentRequestRepository.delete(entity);

        if (!admin) {
            notificationService.notifyAdmins(
                    "Solicitud de ajuste eliminada",
                    workerName + " ha eliminado un ajuste de fichaje del " + formatDate(workDate) + ".",
                    "FICHAJES",
                    NotificationType.WARNING
            );
        }
    }

    @Transactional
    public TimeAdjustmentRequestDto review(Long requestId,
                                           ReviewTimeAdjustmentRequest request,
                                           String reviewerEmail) {
        Worker reviewer = workerRepository.findByEmailIgnoreCase(reviewerEmail)
                .orElseThrow(() -> new EntityNotFoundException("Usuario no encontrado"));
        if (reviewer.getRole() != Role.ADMIN) {
            throw new AccessDeniedException("Solo un administrador puede revisar ajustes de fichaje");
        }
        if (request.status() == TimeAdjustmentRequestStatus.PENDING) {
            throw new IllegalArgumentException("La revisión debe aprobar o rechazar la solicitud");
        }

        TimeAdjustmentRequest adjustmentRequest = timeAdjustmentRequestRepository.findById(requestId)
                .orElseThrow(() -> new EntityNotFoundException("Solicitud de ajuste no encontrada"));

        if (adjustmentRequest.getStatus() != TimeAdjustmentRequestStatus.PENDING) {
            throw new IllegalArgumentException("La solicitud ya fue revisada");
        }

        if (request.status() == TimeAdjustmentRequestStatus.APPROVED) {
            applyAdjustment(adjustmentRequest);
        }

        adjustmentRequest.setStatus(request.status());
        adjustmentRequest.setAdminComment(request.adminComment() == null ? null : request.adminComment().trim());
        adjustmentRequest.setReviewedAt(Instant.now());
        adjustmentRequest.setReviewedByWorker(reviewer);

        TimeAdjustmentRequest saved = timeAdjustmentRequestRepository.save(adjustmentRequest);
        notificationService.notifyWorker(
                saved.getWorker().getId(),
                request.status() == TimeAdjustmentRequestStatus.APPROVED
                        ? "Ajuste de fichaje aprobado"
                        : "Ajuste de fichaje rechazado",
                request.status() == TimeAdjustmentRequestStatus.APPROVED
                        ? "Tu solicitud de ajuste del " + formatDate(saved.getWorkDate()) + " ha sido aplicada."
                        : "Tu solicitud de ajuste del " + formatDate(saved.getWorkDate()) + " ha sido rechazada.",
                "FICHAJES",
                request.status() == TimeAdjustmentRequestStatus.APPROVED
                        ? NotificationType.SUCCESS
                        : NotificationType.WARNING,
                NotificationDeliveryOptions.EMAIL_FALLBACK
        );
        return TimeAdjustmentRequestDto.from(saved);
    }

    private void applyAdjustment(TimeAdjustmentRequest request) {
        validateChronology(request.getRequestedClockIn(), request.getRequestedClockOut());

        TimeEntry entry = request.getTimeEntry();
        if (entry != null) {
            Instant effectiveClockIn = request.getRequestedClockIn() != null
                    ? request.getRequestedClockIn()
                    : entry.getClockIn();
            Instant effectiveClockOut = request.getRequestedClockOut() != null
                    ? request.getRequestedClockOut()
                    : entry.getClockOut();

            if (effectiveClockIn == null) {
                throw new IllegalArgumentException("El fichaje ajustado debe tener hora de entrada");
            }

            validateChronology(effectiveClockIn, effectiveClockOut);
            entry.setClockIn(effectiveClockIn);
            entry.setClockOut(effectiveClockOut);
            entry.setWorkSite(request.getWorkSite());
            if (request.getRequestedClockOut() != null) {
                entry.setAutoClosedAt(null);
                entry.setAutoCloseReason(null);
            }
            request.setTimeEntry(timeEntryRepository.save(entry));
            return;
        }

        if (request.getRequestedClockIn() == null) {
            throw new IllegalArgumentException("Debes indicar la hora de entrada para crear el fichaje ajustado");
        }

        TimeEntry newEntry = new TimeEntry();
        newEntry.setWorker(request.getWorker());
        newEntry.setClockIn(request.getRequestedClockIn());
        newEntry.setClockOut(request.getRequestedClockOut());
        newEntry.setWorkSite(request.getWorkSite());
        request.setTimeEntry(timeEntryRepository.save(newEntry));
    }

    private void applyEditableFields(TimeAdjustmentRequest entity,
                                     Long currentWorkerId,
                                     CreateTimeAdjustmentRequest request) {
        if (request.timeEntryId() == null
                && request.requestedClockIn() == null
                && request.requestedClockOut() == null) {
            throw new IllegalArgumentException("Debes indicar al menos una hora solicitada");
        }

        validateChronology(request.requestedClockIn(), request.requestedClockOut());

        TimeEntry linkedEntry = null;
        if (request.timeEntryId() != null) {
            linkedEntry = timeEntryRepository.findById(request.timeEntryId())
                    .orElseThrow(() -> new EntityNotFoundException("Fichaje no encontrado"));
            if (!linkedEntry.getWorker().getId().equals(currentWorkerId)) {
                throw new AccessDeniedException("Solo puedes solicitar ajustes sobre tus propios fichajes");
            }
        }

        entity.setTimeEntry(linkedEntry);
        entity.setWorkDate(request.workDate());
        entity.setRequestedClockIn(request.requestedClockIn());
        entity.setRequestedClockOut(request.requestedClockOut());
        entity.setWorkSite(request.workSite());
        entity.setReason(request.reason().trim());
    }

    private void validateChronology(Instant requestedClockIn, Instant requestedClockOut) {
        if (requestedClockIn != null && requestedClockOut != null && requestedClockOut.isBefore(requestedClockIn)) {
            throw new IllegalArgumentException("La hora de salida no puede ser anterior a la de entrada");
        }
    }

    private Long resolveLinkedTimeEntryId(Long workerId, LocalDate workDate) {
        ZoneId zoneId = ZoneId.systemDefault();
        Instant start = workDate.atStartOfDay(zoneId).toInstant();
        Instant end = workDate.plusDays(1).atStartOfDay(zoneId).toInstant();
        List<TimeEntry> entries = timeEntryRepository
                .findByWorkerIdAndClockInGreaterThanEqualAndClockInLessThanOrderByClockInDesc(workerId, start, end);
        if (entries.size() == 1) {
            return entries.get(0).getId();
        }
        return null;
    }

    private String formatDate(LocalDate date) {
        String day = String.format("%02d", date.getDayOfMonth());
        String month = String.format("%02d", date.getMonthValue());
        return day + "/" + month + "/" + date.getYear();
    }
}
