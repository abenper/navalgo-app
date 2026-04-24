package com.navalgo.backend.timetracking;

import com.navalgo.backend.common.Role;
import com.navalgo.backend.notification.NotificationService;
import com.navalgo.backend.notification.NotificationType;
import com.navalgo.backend.worker.Worker;
import com.navalgo.backend.worker.WorkerRepository;
import jakarta.persistence.EntityNotFoundException;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.time.LocalDate;
import java.util.List;

@Service
@Transactional(readOnly = true)
public class TimeAdjustmentRequestService {

    private final NotificationService notificationService;
    private final TimeAdjustmentRequestRepository timeAdjustmentRequestRepository;
    private final TimeEntryRepository timeEntryRepository;
    private final WorkerRepository workerRepository;

    public TimeAdjustmentRequestService(NotificationService notificationService,
                                        TimeAdjustmentRequestRepository timeAdjustmentRequestRepository,
                                        TimeEntryRepository timeEntryRepository,
                                        WorkerRepository workerRepository) {
        this.notificationService = notificationService;
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

        TimeAdjustmentRequest entity = new TimeAdjustmentRequest();
        entity.setWorker(worker);
        entity.setTimeEntry(linkedEntry);
        entity.setWorkDate(request.workDate());
        entity.setRequestedClockIn(request.requestedClockIn());
        entity.setRequestedClockOut(request.requestedClockOut());
        entity.setWorkSite(request.workSite());
        entity.setReason(request.reason().trim());
        entity.setStatus(TimeAdjustmentRequestStatus.PENDING);
        entity.setCreatedAt(Instant.now());

        TimeAdjustmentRequest saved = timeAdjustmentRequestRepository.save(entity);
        notificationService.notifyAdmins(
                "Solicitud de ajuste de fichaje",
                worker.getFullName() + " ha solicitado revisar el fichaje del " + formatDate(request.workDate()) + ".",
                "FICHAJES",
                NotificationType.WARNING
        );
        return TimeAdjustmentRequestDto.from(saved);
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
                        : NotificationType.WARNING
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

    private void validateChronology(Instant requestedClockIn, Instant requestedClockOut) {
        if (requestedClockIn != null && requestedClockOut != null && requestedClockOut.isBefore(requestedClockIn)) {
            throw new IllegalArgumentException("La hora de salida no puede ser anterior a la de entrada");
        }
    }

    private String formatDate(LocalDate date) {
        String day = String.format("%02d", date.getDayOfMonth());
        String month = String.format("%02d", date.getMonthValue());
        return day + "/" + month + "/" + date.getYear();
    }
}