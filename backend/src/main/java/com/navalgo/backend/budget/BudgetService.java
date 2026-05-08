package com.navalgo.backend.budget;

import com.navalgo.backend.common.InputSanitizer;
import com.navalgo.backend.common.Role;
import com.navalgo.backend.fleet.Owner;
import com.navalgo.backend.fleet.OwnerRepository;
import com.navalgo.backend.fleet.OwnerType;
import com.navalgo.backend.fleet.Vessel;
import com.navalgo.backend.fleet.VesselRepository;
import com.navalgo.backend.notification.ResendEmailService;
import com.navalgo.backend.worker.Worker;
import com.navalgo.backend.worker.WorkerRepository;
import jakarta.persistence.EntityNotFoundException;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.List;
import java.util.Locale;
import java.util.Optional;

@Service
@Transactional(readOnly = true)
public class BudgetService {

    private final BudgetRepository budgetRepository;
    private final OwnerRepository ownerRepository;
    private final VesselRepository vesselRepository;
    private final WorkerRepository workerRepository;
    private final InputSanitizer inputSanitizer;
    private final ResendEmailService resendEmailService;

    public BudgetService(BudgetRepository budgetRepository,
                         OwnerRepository ownerRepository,
                         VesselRepository vesselRepository,
                         WorkerRepository workerRepository,
                         InputSanitizer inputSanitizer,
                         ResendEmailService resendEmailService) {
        this.budgetRepository = budgetRepository;
        this.ownerRepository = ownerRepository;
        this.vesselRepository = vesselRepository;
        this.workerRepository = workerRepository;
        this.inputSanitizer = inputSanitizer;
        this.resendEmailService = resendEmailService;
    }

    public List<BudgetDto> findAll() {
        return budgetRepository.findAllByOrderByCreatedAtDesc().stream()
                .map(this::toDto)
                .toList();
    }

    public List<BudgetDto> findVisibleBudgets(String currentUserEmail) {
        Worker current = requireActiveWorker(currentUserEmail);
        if (current.getRole() == Role.ADMIN || current.getRole() == Role.COMERCIAL) {
            return findAll();
        }
        if (current.getRole() != Role.CLIENT) {
            throw new AccessDeniedException("No tienes permiso para ver presupuestos");
        }
        if (current.getOwner() == null || current.getOwner().getId() == null) {
            return List.of();
        }
        return budgetRepository.findByOwnerIdOrderByCreatedAtDesc(current.getOwner().getId()).stream()
                .map(this::toDto)
                .toList();
    }

    @Transactional
    public BudgetDto create(CreateBudgetRequest request, String currentUserEmail) {
        Worker current = requireCommercialOrAdmin(currentUserEmail);
        
        Owner owner;
        Vessel vessel;

        if (request.ownerId() != null && request.vesselId() != null) {
            owner = ownerRepository.findById(request.ownerId())
                    .orElseThrow(() -> new EntityNotFoundException("Cliente no encontrado"));
            vessel = vesselRepository.findById(request.vesselId())
                    .orElseThrow(() -> new EntityNotFoundException("Embarcacion no encontrada"));

            if (!vessel.getOwner().getId().equals(owner.getId())) {
                throw new IllegalArgumentException("La embarcacion seleccionada no pertenece a ese cliente");
            }

            String normalizedContactEmail = inputSanitizer.email(request.contactEmail());
            if (normalizedContactEmail != null && !normalizedContactEmail.isBlank()) {
                ensureOwnerEmailAvailable(normalizedContactEmail, owner.getId());
                owner.setEmail(normalizedContactEmail);
                owner = ownerRepository.save(owner);
            }
        } else {
            String email = inputSanitizer.email(request.contactEmail());
            if (email == null || email.isBlank()) {
                throw new IllegalArgumentException("Debe proporcionar un correo electronico valido");
            }

            owner = resolveOwnerByEmail(email).orElseGet(() -> {
                String name = request.newClientName();
                if (name == null || name.isBlank()) {
                    name = email.split("@")[0];
                }
                Owner newOwner = new Owner();
                newOwner.setType(OwnerType.PERSON);
                newOwner.setDisplayName(name);
                newOwner.setDocumentId("PENDIENTE");
                newOwner.setEmail(email);
                return ownerRepository.save(newOwner);
            });

            String vName = request.newVesselName();
            if (vName == null || vName.isBlank()) {
                vName = "Embarcacion General";
            }
            final String finalVName = vName;
            final Owner finalOwner = owner;
            final Long finalOwnerId = owner.getId();
            vessel = vesselRepository.findByOwnerId(finalOwnerId).stream()
                    .filter(v -> v.getName().equalsIgnoreCase(finalVName))
                    .findFirst()
                    .orElseGet(() -> {
                        Vessel newVessel = new Vessel();
                        newVessel.setOwner(finalOwner);
                        newVessel.setName(finalVName);
                        newVessel.setRegistrationNumber(
                                buildPlaceholderRegistrationNumber(finalOwnerId, finalVName)
                        );
                        return vesselRepository.save(newVessel);
                    });
        }

        Budget budget = new Budget();
        budget.setOwner(owner);
        budget.setVessel(vessel);
        budget.setCreatedByWorker(current);
        budget.setTitle(inputSanitizer.requiredText(request.title(), "El titulo del presupuesto", 255));
        budget.setDescription(inputSanitizer.optionalText(request.description(), 3000));
        budget.setAmount(request.amount());
        budget.setCurrency(normalizeCurrency(request.currency()));
        budget.setPdfUrl(inputSanitizer.optionalUrl(request.pdfUrl(), 2000));
        budget.setStatus(BudgetStatus.DRAFT);
        budget.setCreatedAt(Instant.now());
        budget.setUpdatedAt(Instant.now());

        return toDto(budgetRepository.save(budget));
    }

    @Transactional
    public BudgetDto updateStatus(Long budgetId,
                                  UpdateBudgetStatusRequest request,
                                  String currentUserEmail) {
        Worker current = requireActiveWorker(currentUserEmail);
        Budget budget = budgetRepository.findById(budgetId)
                .orElseThrow(() -> new EntityNotFoundException("Presupuesto no encontrado"));

        BudgetStatus previousStatus = budget.getStatus();
        BudgetStatus nextStatus = request.status();

        if (current.getRole() == Role.ADMIN || current.getRole() == Role.COMERCIAL) {
            // Admin/commercial can moderate the workflow, including marking as sent.
        } else if (current.getRole() == Role.CLIENT) {
            ensureClientOwnsBudget(current, budget);
            if (nextStatus != BudgetStatus.ACCEPTED && nextStatus != BudgetStatus.REJECTED) {
                throw new AccessDeniedException("El cliente solo puede aceptar o rechazar presupuestos");
            }
            if (previousStatus != BudgetStatus.SENT) {
                throw new IllegalArgumentException("Solo puedes responder presupuestos enviados y pendientes");
            }
        } else {
            throw new AccessDeniedException("No tienes permiso para gestionar presupuestos");
        }

        budget.setStatus(nextStatus);
        budget.setClientObservations(inputSanitizer.optionalText(request.clientObservations(), 2000));
        budget.setUpdatedAt(Instant.now());

        if (nextStatus == BudgetStatus.SENT && previousStatus != BudgetStatus.SENT) {
            budget.setSentAt(Instant.now());
            sendBudgetEmail(budget);
        }

        if ((nextStatus == BudgetStatus.ACCEPTED || nextStatus == BudgetStatus.REJECTED)
                && budget.getClientDecidedAt() == null) {
            budget.setClientDecidedAt(Instant.now());
        }

        return toDto(budgetRepository.save(budget));
    }

    @Transactional
    public void delete(Long budgetId, String currentUserEmail) {
        requireCommercialOrAdmin(currentUserEmail);
        Budget budget = budgetRepository.findById(budgetId)
                .orElseThrow(() -> new EntityNotFoundException("Presupuesto no encontrado"));
        budgetRepository.delete(budget);
    }

    private void sendBudgetEmail(Budget budget) {
        String ownerEmail = budget.getOwner().getEmail();
        if (ownerEmail == null || ownerEmail.isBlank()) {
            throw new IllegalArgumentException("El cliente no tiene correo electronico para enviar el presupuesto");
        }
        boolean clientHasAccount = workerRepository.findByOwner_Id(budget.getOwner().getId())
                .filter(worker -> worker.getRole() == Role.CLIENT)
                .isPresent();
        resendEmailService.sendBudgetNotification(
                budget.getOwner().getDisplayName(),
                ownerEmail,
                budget.getTitle(),
                budget.getVessel().getName(),
                budget.getAmount(),
                budget.getCurrency(),
                budget.getPdfUrl(),
                clientHasAccount
        );
    }

    private Worker requireCommercialOrAdmin(String email) {
        Worker worker = requireActiveWorker(email);
        if (worker.getRole() != Role.ADMIN && worker.getRole() != Role.COMERCIAL) {
            throw new AccessDeniedException("No tienes permiso para gestionar presupuestos");
        }
        return worker;
    }

    private Worker requireActiveWorker(String email) {
        Worker worker = workerRepository.findByEmailIgnoreCase(email)
                .orElseThrow(() -> new EntityNotFoundException("Usuario no encontrado"));
        if (!worker.isActive()) {
            throw new AccessDeniedException("Usuario inactivo");
        }
        return worker;
    }

    private void ensureClientOwnsBudget(Worker client, Budget budget) {
        if (client.getOwner() == null || client.getOwner().getId() == null) {
            throw new AccessDeniedException("Tu cuenta no esta asociada a un cliente valido");
        }
        if (!client.getOwner().getId().equals(budget.getOwner().getId())) {
            throw new AccessDeniedException("No puedes responder a presupuestos de otro cliente");
        }
    }

    private String normalizeCurrency(String currency) {
        String normalized = inputSanitizer.optionalText(currency, 3);
        if (normalized == null || normalized.isBlank()) {
            return "EUR";
        }
        return normalized.toUpperCase(Locale.ROOT);
    }

    private String buildPlaceholderRegistrationNumber(Long ownerId, String vesselName) {
        String baseName = vesselName == null ? "VESSEL" : vesselName.trim().toUpperCase(Locale.ROOT);
        baseName = baseName.replaceAll("[^A-Z0-9]+", "-");
        if (baseName.isBlank()) {
            baseName = "VESSEL";
        }
        if (baseName.length() > 18) {
            baseName = baseName.substring(0, 18);
        }
        String ownerPart = ownerId == null ? "0" : Long.toString(ownerId);
        String suffix = Long.toString(System.currentTimeMillis());
        if (suffix.length() > 6) {
            suffix = suffix.substring(suffix.length() - 6);
        }
        return "TMP-" + ownerPart + "-" + baseName + "-" + suffix;
    }

    private void ensureOwnerEmailAvailable(String email, Long ownerId) {
        boolean exists = ownerId == null
                ? ownerRepository.existsByEmailIgnoreCase(email)
                : ownerRepository.existsByEmailIgnoreCaseAndIdNot(email, ownerId);
        if (exists) {
            throw new IllegalArgumentException("Ya existe un cliente con ese correo electronico");
        }
    }

    private Optional<Owner> resolveOwnerByEmail(String email) {
        Optional<Owner> ownerByEmail = ownerRepository.findByEmailIgnoreCase(email);
        if (ownerByEmail.isPresent()) {
            return ownerByEmail;
        }
        return workerRepository.findByEmailIgnoreCase(email)
                .map(Worker::getOwner)
                .filter(owner -> owner != null && owner.getId() != null);
    }

    private BudgetDto toDto(Budget budget) {
        boolean clientHasAccount = workerRepository.findByOwner_Id(budget.getOwner().getId())
                .filter(worker -> worker.getRole() == Role.CLIENT)
                .isPresent();
        return new BudgetDto(
                budget.getId(),
                budget.getOwner().getId(),
                budget.getOwner().getDisplayName(),
                budget.getOwner().getEmail(),
                clientHasAccount,
                budget.getVessel().getId(),
                budget.getVessel().getName(),
                budget.getCreatedByWorker().getId(),
                budget.getCreatedByWorker().getFullName(),
                budget.getTitle(),
                budget.getDescription(),
                budget.getAmount(),
                budget.getCurrency(),
                budget.getPdfUrl(),
                budget.getStatus(),
                budget.getClientObservations(),
                budget.getSentAt(),
                budget.getClientDecidedAt(),
                budget.getCreatedAt(),
                budget.getUpdatedAt()
        );
    }
}
