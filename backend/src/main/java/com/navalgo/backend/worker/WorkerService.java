package com.navalgo.backend.worker;

import com.navalgo.backend.auth.RefreshTokenService;
import com.navalgo.backend.common.InputSanitizer;
import jakarta.persistence.EntityNotFoundException;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.security.SecureRandom;
import java.time.LocalDate;
import java.util.List;

@Service
@Transactional(readOnly = true)
public class WorkerService {

    private final WorkerRepository workerRepository;
    private final PasswordEncoder passwordEncoder;
    private final RefreshTokenService refreshTokenService;
    private final InputSanitizer inputSanitizer;
    private final SecureRandom secureRandom = new SecureRandom();
    private static final String PASSWORD_CHARS = "ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789@#$%";

    public WorkerService(WorkerRepository workerRepository,
                         PasswordEncoder passwordEncoder,
                         RefreshTokenService refreshTokenService,
                         InputSanitizer inputSanitizer) {
        this.workerRepository = workerRepository;
        this.passwordEncoder = passwordEncoder;
        this.refreshTokenService = refreshTokenService;
        this.inputSanitizer = inputSanitizer;
    }

    public List<WorkerDto> findAll() {
        return workerRepository.findAll().stream().map(WorkerDto::from).toList();
    }

    public WorkerDto findOwnProfile(String email) {
        Worker worker = workerRepository.findByEmailIgnoreCase(email)
                .orElseThrow(() -> new EntityNotFoundException("Usuario no encontrado"));
        return WorkerDto.from(worker);
    }

    public CreateWorkerResponse create(CreateWorkerRequest request) {
        workerRepository.findByEmailIgnoreCase(request.email()).ifPresent(existing -> {
            throw new IllegalArgumentException("Ya existe un trabajador con ese email");
        });

        if (request.password() != null && !request.password().isBlank() && !isStrongPassword(request.password().trim())) {
            throw new IllegalArgumentException("La contrasena debe tener minimo 12 caracteres e incluir mayuscula, minuscula, numero y simbolo");
        }

        String rawPassword = (request.password() == null || request.password().isBlank())
                ? generateTemporaryPassword(12)
                : request.password().trim();
        boolean generatedPassword = request.password() == null || request.password().isBlank();

        Worker worker = new Worker();
        worker.setFullName(inputSanitizer.requiredText(request.fullName(), "El nombre", 255));
        worker.setEmail(inputSanitizer.email(request.email()));
        worker.setPasswordHash(passwordEncoder.encode(rawPassword));
        worker.setSpeciality(inputSanitizer.optionalText(request.speciality(), 255));
        worker.setRole(request.role());
        worker.setActive(true);
        worker.setMustChangePassword(true);
        worker.setCanEditWorkOrders(request.canEditWorkOrders());
        worker.setContractStartDate(request.contractStartDate() != null ? request.contractStartDate() : LocalDate.now());

        Worker saved = workerRepository.save(worker);
        return new CreateWorkerResponse(WorkerDto.from(saved), generatedPassword ? rawPassword : null);
    }

    @Transactional
    public WorkerDto update(Long workerId, UpdateWorkerRequest request) {
        Worker worker = workerRepository.findById(workerId)
                .orElseThrow(() -> new EntityNotFoundException("Trabajador no encontrado"));

        workerRepository.findByEmailIgnoreCase(request.email()).ifPresent(existing -> {
            if (!existing.getId().equals(workerId)) {
                throw new IllegalArgumentException("Ya existe un trabajador con ese email");
            }
        });

        worker.setFullName(inputSanitizer.requiredText(request.fullName(), "El nombre", 255));
        worker.setEmail(inputSanitizer.email(request.email()));
        worker.setSpeciality(inputSanitizer.optionalText(request.speciality(), 255));
        worker.setRole(request.role());
        worker.setCanEditWorkOrders(request.canEditWorkOrders());
        worker.setContractStartDate(request.contractStartDate());
        return WorkerDto.from(workerRepository.save(worker));
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
        return WorkerDto.from(workerRepository.save(worker));
    }

    @Transactional
    public void delete(Long workerId) {
        if (!workerRepository.existsById(workerId)) {
            throw new EntityNotFoundException("Trabajador no encontrado");
        }
        refreshTokenService.revokeAllForWorker(workerId);
        workerRepository.deleteById(workerId);
    }

    @Transactional
    public ResetWorkerPasswordResponse resetPassword(Long workerId) {
        Worker worker = workerRepository.findById(workerId)
                .orElseThrow(() -> new EntityNotFoundException("Trabajador no encontrado"));

        String temporaryPassword = generateTemporaryPassword(12);
        worker.setPasswordHash(passwordEncoder.encode(temporaryPassword));
        worker.setMustChangePassword(true);
        refreshTokenService.revokeAllForWorker(workerId);
        workerRepository.save(worker);

        return new ResetWorkerPasswordResponse(worker.getId(), worker.getEmail(), temporaryPassword);
    }

    @Transactional
    public WorkerDto setWorkOrderEditPermission(Long workerId, boolean canEditWorkOrders) {
        Worker worker = workerRepository.findById(workerId)
                .orElseThrow(() -> new EntityNotFoundException("Trabajador no encontrado"));
        worker.setCanEditWorkOrders(canEditWorkOrders);
        return WorkerDto.from(workerRepository.save(worker));
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
    public WorkerDto setActive(Long workerId, boolean active) {
        Worker worker = workerRepository.findById(workerId)
                .orElseThrow(() -> new EntityNotFoundException("Trabajador no encontrado"));
        worker.setActive(active);
        if (!active) {
            refreshTokenService.revokeAllForWorker(workerId);
        }
        return WorkerDto.from(workerRepository.save(worker));
    }

    @Transactional
    public WorkerDto updatePhoto(Long workerId, String photoUrl, boolean isAdmin, String requesterEmail) {
        Worker worker = workerRepository.findById(workerId)
                .orElseThrow(() -> new EntityNotFoundException("Trabajador no encontrado"));
        if (!isAdmin && !worker.getEmail().equalsIgnoreCase(requesterEmail)) {
            throw new org.springframework.security.access.AccessDeniedException("Solo puedes actualizar tu propia foto");
        }
        worker.setPhotoUrl(photoUrl);
        return WorkerDto.from(workerRepository.save(worker));
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
