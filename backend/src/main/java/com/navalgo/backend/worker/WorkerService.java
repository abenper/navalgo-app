package com.navalgo.backend.worker;

import com.navalgo.backend.auth.EmailVerificationTokenRepository;
import com.navalgo.backend.auth.PasswordResetTokenRepository;
import com.navalgo.backend.auth.RefreshTokenService;
import com.navalgo.backend.auth.RefreshTokenRepository;
import com.navalgo.backend.auth.RegistrationInvitation;
import com.navalgo.backend.auth.RegistrationInvitationRepository;
import com.navalgo.backend.auth.RegistrationInvitationService;
import com.navalgo.backend.budget.BudgetRepository;
import com.navalgo.backend.common.InputSanitizer;
import com.navalgo.backend.common.Role;
import com.navalgo.backend.leave.LeaveRequestRepository;
import com.navalgo.backend.notification.NotificationRepository;
import com.navalgo.backend.notification.WorkerPushTokenRepository;
import com.navalgo.backend.timetracking.TimeAdjustmentRequestRepository;
import com.navalgo.backend.timetracking.TimeEntryRepository;
import com.navalgo.backend.workorder.MaterialRevisionRequestRepository;
import com.navalgo.backend.workorder.WorkOrderAttachmentRepository;
import com.navalgo.backend.workorder.WorkOrderChecklistItemRepository;
import com.navalgo.backend.workorder.WorkOrderRepository;
import jakarta.persistence.EntityNotFoundException;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.transaction.annotation.Transactional;

import java.security.SecureRandom;
import java.time.LocalDate;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

@Service
@Transactional(readOnly = true)
public class WorkerService {
    private static final String SUPERADMIN_EMAIL = "admin@naval-go.com";

    private final WorkerRepository workerRepository;
    private final PasswordEncoder passwordEncoder;
    private final RefreshTokenService refreshTokenService;
    private final RefreshTokenRepository refreshTokenRepository;
    private final WorkOrderRepository workOrderRepository;
    private final InputSanitizer inputSanitizer;
    private final RegistrationInvitationService registrationInvitationService;
    private final RegistrationInvitationRepository registrationInvitationRepository;
    private final EmailVerificationTokenRepository emailVerificationTokenRepository;
    private final PasswordResetTokenRepository passwordResetTokenRepository;
    private final NotificationRepository notificationRepository;
    private final WorkerPushTokenRepository workerPushTokenRepository;
    private final LeaveRequestRepository leaveRequestRepository;
    private final TimeAdjustmentRequestRepository timeAdjustmentRequestRepository;
    private final TimeEntryRepository timeEntryRepository;
    private final WorkOrderAttachmentRepository workOrderAttachmentRepository;
    private final WorkOrderChecklistItemRepository workOrderChecklistItemRepository;
    private final MaterialRevisionRequestRepository materialRevisionRequestRepository;
    private final BudgetRepository budgetRepository;
    private final SecureRandom secureRandom = new SecureRandom();
    private static final String PASSWORD_CHARS = "ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789@#$%";

    public WorkerService(WorkerRepository workerRepository,
                         PasswordEncoder passwordEncoder,
                         RefreshTokenService refreshTokenService,
                         RefreshTokenRepository refreshTokenRepository,
                         WorkOrderRepository workOrderRepository,
                         InputSanitizer inputSanitizer,
                         RegistrationInvitationService registrationInvitationService,
                         RegistrationInvitationRepository registrationInvitationRepository,
                         EmailVerificationTokenRepository emailVerificationTokenRepository,
                         PasswordResetTokenRepository passwordResetTokenRepository,
                         NotificationRepository notificationRepository,
                         WorkerPushTokenRepository workerPushTokenRepository,
                         LeaveRequestRepository leaveRequestRepository,
                         TimeAdjustmentRequestRepository timeAdjustmentRequestRepository,
                         TimeEntryRepository timeEntryRepository,
                         WorkOrderAttachmentRepository workOrderAttachmentRepository,
                         WorkOrderChecklistItemRepository workOrderChecklistItemRepository,
                         MaterialRevisionRequestRepository materialRevisionRequestRepository,
                         BudgetRepository budgetRepository) {
        this.workerRepository = workerRepository;
        this.passwordEncoder = passwordEncoder;
        this.refreshTokenService = refreshTokenService;
        this.refreshTokenRepository = refreshTokenRepository;
        this.workOrderRepository = workOrderRepository;
        this.inputSanitizer = inputSanitizer;
        this.registrationInvitationService = registrationInvitationService;
        this.registrationInvitationRepository = registrationInvitationRepository;
        this.emailVerificationTokenRepository = emailVerificationTokenRepository;
        this.passwordResetTokenRepository = passwordResetTokenRepository;
        this.notificationRepository = notificationRepository;
        this.workerPushTokenRepository = workerPushTokenRepository;
        this.leaveRequestRepository = leaveRequestRepository;
        this.timeAdjustmentRequestRepository = timeAdjustmentRequestRepository;
        this.timeEntryRepository = timeEntryRepository;
        this.workOrderAttachmentRepository = workOrderAttachmentRepository;
        this.workOrderChecklistItemRepository = workOrderChecklistItemRepository;
        this.materialRevisionRequestRepository = materialRevisionRequestRepository;
        this.budgetRepository = budgetRepository;
    }

    public List<WorkerDto> findAll() {
        List<Worker> workers = workerRepository.findAll();
        Set<Long> pendingRegistrationWorkerIds = findPendingRegistrationWorkerIds(workers);
        return workers.stream()
                .map(worker -> WorkerDto.from(worker, !pendingRegistrationWorkerIds.contains(worker.getId())))
                .toList();
    }

    public WorkerDto findOwnProfile(String email) {
        Worker worker = workerRepository.findByEmailIgnoreCase(email)
                .orElseThrow(() -> new EntityNotFoundException("Usuario no encontrado"));
        return WorkerDto.from(worker, isRegistrationCompleted(worker.getId()));
    }

    @Transactional
    public CreateWorkerResponse create(CreateWorkerRequest request, String requesterEmail) {
        ensureCanManageAdminRole(request.role(), requesterEmail);
        workerRepository.findByEmailIgnoreCase(request.email()).ifPresent(existing -> {
            throw new IllegalArgumentException("Ya existe un trabajador con ese email");
        });

        Worker worker = new Worker();
        worker.setFullName(inputSanitizer.requiredText(request.fullName(), "El nombre", 255));
        worker.setEmail(inputSanitizer.email(request.email()));
        worker.setPasswordHash(passwordEncoder.encode(generateTemporaryPassword(24)));
        worker.setSpeciality(inputSanitizer.optionalText(request.speciality(), 255));
        worker.setPhonePrefix(inputSanitizer.requiredText(request.phonePrefix(), "El prefijo del telefono", 8));
        worker.setPhone(inputSanitizer.requiredText(request.phone(), "El telefono", 32));
        worker.setRole(request.role());
        worker.setActive(true);
        worker.setMustChangePassword(false);
        worker.setCanEditWorkOrders(request.role() == Role.WORKER && request.canEditWorkOrders());
        worker.setEmailVerified(request.role() != Role.CLIENT);
        worker.setContractStartDate(request.contractStartDate() != null ? request.contractStartDate() : LocalDate.now());

        Worker saved = workerRepository.save(worker);
        boolean invitationEmailSent = registrationInvitationService.issueInvitation(saved);
        return new CreateWorkerResponse(WorkerDto.from(saved, false), invitationEmailSent);
    }

    @Transactional
    public WorkerDto update(Long workerId, UpdateWorkerRequest request, String requesterEmail) {
        Worker worker = workerRepository.findById(workerId)
                .orElseThrow(() -> new EntityNotFoundException("Trabajador no encontrado"));
        ensureCanManageTarget(worker, requesterEmail);
        ensureCanManageAdminRole(request.role(), requesterEmail);

        workerRepository.findByEmailIgnoreCase(request.email()).ifPresent(existing -> {
            if (!existing.getId().equals(workerId)) {
                throw new IllegalArgumentException("Ya existe un trabajador con ese email");
            }
        });

        worker.setFullName(inputSanitizer.requiredText(request.fullName(), "El nombre", 255));
        worker.setEmail(inputSanitizer.email(request.email()));
        worker.setSpeciality(inputSanitizer.optionalText(request.speciality(), 255));
        worker.setPhonePrefix(inputSanitizer.requiredText(request.phonePrefix(), "El prefijo del telefono", 8));
        worker.setPhone(inputSanitizer.requiredText(request.phone(), "El telefono", 32));
        worker.setRole(request.role());
        worker.setCanEditWorkOrders(request.role() == Role.WORKER && request.canEditWorkOrders());
        worker.setContractStartDate(request.contractStartDate());
        Worker saved = workerRepository.save(worker);
        return WorkerDto.from(saved, isRegistrationCompleted(saved.getId()));
    }

    @Transactional
    public WorkerDto updateOwnProfile(String currentEmail, UpdateOwnProfileRequest request) {
        Worker worker = workerRepository.findByEmailIgnoreCase(currentEmail)
                .orElseThrow(() -> new EntityNotFoundException("Usuario no encontrado"));

        workerRepository.findByEmailIgnoreCase(request.email()).ifPresent(existing -> {
            if (!existing.getId().equals(worker.getId())) {
                throw new IllegalArgumentException("Ya existe un trabajador con ese email");
            }
        });

        worker.setFullName(inputSanitizer.requiredText(request.fullName(), "El nombre", 255));
        worker.setEmail(inputSanitizer.email(request.email()));
        worker.setSpeciality(inputSanitizer.optionalText(request.speciality(), 255));
        Worker saved = workerRepository.save(worker);
        return WorkerDto.from(saved, isRegistrationCompleted(saved.getId()));
    }

    @Transactional
    public void delete(Long workerId, String requesterEmail) {
        Worker worker = workerRepository.findById(workerId)
                .orElseThrow(() -> new EntityNotFoundException("Trabajador no encontrado"));
        ensureCanManageTarget(worker, requesterEmail);
        ensureNoProtectedBusinessHistory(workerId);

        refreshTokenService.revokeAllForWorker(workerId);
        registrationInvitationRepository.deleteByWorker_Id(workerId);
        emailVerificationTokenRepository.deleteByWorker_Id(workerId);
        passwordResetTokenRepository.deleteByWorker_Id(workerId);
        refreshTokenRepository.deleteByWorkerId(workerId);
        workerPushTokenRepository.deleteByWorkerId(workerId);
        notificationRepository.deleteByWorkerId(workerId);
        workOrderRepository.removeWorkerFromAllWorkOrders(workerId);
        workOrderRepository.clearSignedByWorker(workerId);
        workOrderAttachmentRepository.clearUploadedByWorker(workerId);
        workOrderChecklistItemRepository.clearCheckedByWorker(workerId);
        timeAdjustmentRequestRepository.clearReviewedByWorker(workerId);
        materialRevisionRequestRepository.clearReviewedByWorker(workerId);
        timeAdjustmentRequestRepository.deleteByWorkerId(workerId);
        leaveRequestRepository.deleteByWorkerId(workerId);
        timeEntryRepository.deleteByWorkerId(workerId);
        try {
            workerRepository.delete(worker);
            workerRepository.flush();
        } catch (DataIntegrityViolationException exception) {
            throw new IllegalArgumentException(
                    "No se puede eliminar el trabajador porque conserva historico de negocio asociado. Desactivalo si necesitas mantener esa trazabilidad."
            );
        }
    }

    @Transactional
    public ResetWorkerPasswordResponse resetPassword(Long workerId, String requesterEmail) {
        Worker worker = workerRepository.findById(workerId)
                .orElseThrow(() -> new EntityNotFoundException("Trabajador no encontrado"));
        ensureCanManageTarget(worker, requesterEmail);

        String temporaryPassword = generateTemporaryPassword(12);
        worker.setPasswordHash(passwordEncoder.encode(temporaryPassword));
        worker.setMustChangePassword(true);
        refreshTokenService.revokeAllForWorker(workerId);
        workerRepository.save(worker);

        return new ResetWorkerPasswordResponse(worker.getId(), worker.getEmail(), temporaryPassword);
    }

    @Transactional
    public WorkerDto setWorkOrderEditPermission(Long workerId, boolean canEditWorkOrders, String requesterEmail) {
        Worker worker = workerRepository.findById(workerId)
                .orElseThrow(() -> new EntityNotFoundException("Trabajador no encontrado"));
        ensureCanManageTarget(worker, requesterEmail);
        worker.setCanEditWorkOrders(canEditWorkOrders);
        Worker saved = workerRepository.save(worker);
        return WorkerDto.from(saved, isRegistrationCompleted(saved.getId()));
    }

    @Transactional
    public void changeOwnPassword(String email, String currentPassword, String newPassword) {
        if (newPassword == null || newPassword.isBlank() || !isStrongPassword(newPassword)) {
            throw new IllegalArgumentException("La nueva contrasena debe tener minimo 12 caracteres e incluir mayuscula, minuscula, numero y simbolo");
        }

        Worker worker = workerRepository.findByEmailIgnoreCase(email)
                .orElseThrow(() -> new EntityNotFoundException("Usuario no encontrado"));

        if (!passwordEncoder.matches(currentPassword, worker.getPasswordHash())) {
            throw new IllegalArgumentException("La contrasena actual no es correcta");
        }

        worker.setPasswordHash(passwordEncoder.encode(newPassword));
        worker.setMustChangePassword(false);
        refreshTokenService.revokeAllForWorker(worker.getId());
        workerRepository.save(worker);
    }

    @Transactional
    public WorkerDto setActive(Long workerId, boolean active, String requesterEmail) {
        Worker worker = workerRepository.findById(workerId)
                .orElseThrow(() -> new EntityNotFoundException("Trabajador no encontrado"));
        ensureCanManageTarget(worker, requesterEmail);
        worker.setActive(active);
        if (!active) {
            refreshTokenService.revokeAllForWorker(workerId);
        }
        Worker saved = workerRepository.save(worker);
        return WorkerDto.from(saved, isRegistrationCompleted(saved.getId()));
    }

    @Transactional
    public WorkerDto updatePhoto(Long workerId, String photoUrl, boolean isAdmin, String requesterEmail) {
        Worker worker = workerRepository.findById(workerId)
                .orElseThrow(() -> new EntityNotFoundException("Trabajador no encontrado"));
        ensureCanUpdatePhoto(worker, isAdmin, requesterEmail);
        worker.setPhotoUrl(photoUrl);
        Worker saved = workerRepository.save(worker);
        return WorkerDto.from(saved, isRegistrationCompleted(saved.getId()));
    }

    public String resolvePhotoOwnerEmail(Long workerId, boolean isAdmin, String requesterEmail) {
        Worker worker = workerRepository.findById(workerId)
                .orElseThrow(() -> new EntityNotFoundException("Trabajador no encontrado"));
        ensureCanUpdatePhoto(worker, isAdmin, requesterEmail);
        return worker.getEmail();
    }

    private boolean isRegistrationCompleted(Long workerId) {
        return !registrationInvitationRepository.existsByWorker_Id(workerId);
    }

    private Set<Long> findPendingRegistrationWorkerIds(List<Worker> workers) {
        List<Long> workerIds = workers.stream()
                .map(Worker::getId)
                .toList();
        if (workerIds.isEmpty()) {
            return Set.of();
        }

        Set<Long> pendingRegistrationWorkerIds = new HashSet<>();
        for (RegistrationInvitation invitation : registrationInvitationRepository.findByWorker_IdIn(workerIds)) {
            pendingRegistrationWorkerIds.add(invitation.getWorker().getId());
        }
        return pendingRegistrationWorkerIds;
    }

    private void ensureCanManageAdminRole(Role requestedRole, String requesterEmail) {
        if (requestedRole == Role.ADMIN && !isSuperAdmin(requesterEmail)) {
            throw new org.springframework.security.access.AccessDeniedException("Solo el superadmin puede asignar el rol de administrador");
        }
    }

    private void ensureCanManageTarget(Worker target, String requesterEmail) {
        if (target.getRole() == Role.ADMIN && !isSuperAdmin(requesterEmail)) {
            throw new org.springframework.security.access.AccessDeniedException("Solo el superadmin puede modificar cuentas de administrador");
        }
    }

    private void ensureCanUpdatePhoto(Worker worker, boolean isAdmin, String requesterEmail) {
        if (worker.getEmail().equalsIgnoreCase(requesterEmail)) {
            return;
        }
        if (!isAdmin) {
            throw new org.springframework.security.access.AccessDeniedException("Solo puedes actualizar tu propia foto");
        }
        ensureCanManageTarget(worker, requesterEmail);
    }

    private void ensureNoProtectedBusinessHistory(Long workerId) {
        boolean hasCreatedBudgets = budgetRepository.existsByCreatedByWorkerId(workerId);
        boolean hasRequestedMaterialRevisions = materialRevisionRequestRepository.existsByRequestedByWorkerId(workerId);

        if (!hasCreatedBudgets && !hasRequestedMaterialRevisions) {
            return;
        }

        if (hasCreatedBudgets && hasRequestedMaterialRevisions) {
            throw new IllegalArgumentException(
                    "No se puede eliminar el trabajador porque ha creado presupuestos y solicitudes de revision de material. Desactivalo si necesitas conservar ese historico."
            );
        }
        if (hasCreatedBudgets) {
            throw new IllegalArgumentException(
                    "No se puede eliminar el trabajador porque ha creado presupuestos. Desactivalo si necesitas conservar ese historico."
            );
        }
        throw new IllegalArgumentException(
                "No se puede eliminar el trabajador porque ha creado solicitudes de revision de material. Desactivalo si necesitas conservar ese historico."
        );
    }

    private boolean isSuperAdmin(String email) {
        return email != null && email.equalsIgnoreCase(SUPERADMIN_EMAIL);
    }

    private String generateTemporaryPassword(int length) {
        StringBuilder password = new StringBuilder(length);
        for (int i = 0; i < length; i++) {
            int index = secureRandom.nextInt(PASSWORD_CHARS.length());
            password.append(PASSWORD_CHARS.charAt(index));
        }
        return password.toString();
    }

    private boolean isStrongPassword(String password) {
        if (password.length() < 12) {
            return false;
        }
        boolean hasUpper = false;
        boolean hasLower = false;
        boolean hasDigit = false;
        boolean hasSymbol = false;

        for (char c : password.toCharArray()) {
            if (Character.isUpperCase(c)) {
                hasUpper = true;
            } else if (Character.isLowerCase(c)) {
                hasLower = true;
            } else if (Character.isDigit(c)) {
                hasDigit = true;
            } else {
                hasSymbol = true;
            }
        }

        return hasUpper && hasLower && hasDigit && hasSymbol;
    }
}
