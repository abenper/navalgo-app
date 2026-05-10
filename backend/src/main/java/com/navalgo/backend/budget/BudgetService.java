package com.navalgo.backend.budget;

import com.navalgo.backend.common.InputSanitizer;
import com.navalgo.backend.common.Role;
import com.navalgo.backend.fleet.Owner;
import com.navalgo.backend.fleet.OwnerRepository;
import com.navalgo.backend.fleet.OwnerType;
import com.navalgo.backend.fleet.Vessel;
import com.navalgo.backend.fleet.VesselRepository;
import com.navalgo.backend.notification.NotificationService;
import com.navalgo.backend.notification.NotificationType;
import com.navalgo.backend.notification.ResendEmailService;
import com.navalgo.backend.worker.Worker;
import com.navalgo.backend.worker.WorkerRepository;
import jakarta.persistence.EntityNotFoundException;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.Instant;
import java.util.Collection;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Optional;
import java.util.Set;

@Service
@Transactional(readOnly = true)
public class BudgetService {

    private static final Logger log = LoggerFactory.getLogger(BudgetService.class);

    private final BudgetRepository budgetRepository;
    private final OwnerRepository ownerRepository;
    private final VesselRepository vesselRepository;
    private final WorkerRepository workerRepository;
    private final InputSanitizer inputSanitizer;
    private final ResendEmailService resendEmailService;
    private final NotificationService notificationService;

    public BudgetService(BudgetRepository budgetRepository,
                         OwnerRepository ownerRepository,
                         VesselRepository vesselRepository,
                         WorkerRepository workerRepository,
                         InputSanitizer inputSanitizer,
                         ResendEmailService resendEmailService,
                         NotificationService notificationService) {
        this.budgetRepository = budgetRepository;
        this.ownerRepository = ownerRepository;
        this.vesselRepository = vesselRepository;
        this.workerRepository = workerRepository;
        this.inputSanitizer = inputSanitizer;
        this.resendEmailService = resendEmailService;
        this.notificationService = notificationService;
    }

    public List<BudgetDto> findAll() {
        return toDtos(budgetRepository.findAllByOrderByCreatedAtDesc());
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
        return toDtos(budgetRepository.findByOwnerIdOrderByCreatedAtDesc(current.getOwner().getId()));
    }

    @Transactional
    public BudgetDto create(CreateBudgetRequest request, String currentUserEmail) {
        Worker current = requireCommercialOrAdmin(currentUserEmail);
        
        Owner owner;
        Vessel vessel;

        if (request.ownerId() != null) {
            owner = ownerRepository.findById(request.ownerId())
                    .orElseThrow(() -> new EntityNotFoundException("Cliente no encontrado"));

            String normalizedContactEmail = inputSanitizer.email(request.contactEmail());
            if (normalizedContactEmail != null && !normalizedContactEmail.isBlank()) {
                ensureOwnerEmailAvailable(normalizedContactEmail, owner.getId());
                owner.setEmail(normalizedContactEmail);
                owner = ownerRepository.save(owner);
            }

            if (request.vesselId() != null) {
                vessel = vesselRepository.findById(request.vesselId())
                        .orElseThrow(() -> new EntityNotFoundException("Embarcacion no encontrada"));

                if (!vessel.getOwner().getId().equals(owner.getId())) {
                    throw new IllegalArgumentException("La embarcacion seleccionada no pertenece a ese cliente");
                }
            } else {
                vessel = findOrCreatePlaceholderVessel(owner);
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

            vessel = findOrCreatePlaceholderVessel(owner);
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
    public BudgetDto assignVessel(Long budgetId,
                                  AssignBudgetVesselRequest request,
                                  String currentUserEmail) {
        Worker current = requireActiveWorker(currentUserEmail);
        Budget budget = budgetRepository.findById(budgetId)
                .orElseThrow(() -> new EntityNotFoundException("Presupuesto no encontrado"));
        Vessel vessel = vesselRepository.findById(request.vesselId())
                .orElseThrow(() -> new EntityNotFoundException("Embarcacion no encontrada"));

        if (!vessel.getOwner().getId().equals(budget.getOwner().getId())) {
            throw new IllegalArgumentException("La embarcacion seleccionada no pertenece a este cliente");
        }

        if (current.getRole() == Role.CLIENT) {
            ensureClientOwnsBudget(current, budget);
        } else if (current.getRole() != Role.ADMIN && current.getRole() != Role.COMERCIAL) {
            throw new AccessDeniedException("No tienes permiso para actualizar la embarcacion del presupuesto");
        }

        budget.setVessel(vessel);
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

        if (current.getRole() == Role.CLIENT
                && previousStatus == BudgetStatus.SENT
                && (nextStatus == BudgetStatus.ACCEPTED || nextStatus == BudgetStatus.REJECTED)) {
            notifyCommercialsAboutClientDecision(budget, nextStatus);
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
        boolean clientHasAccount = workerRepository.existsByRoleAndOwner_Id(
                Role.CLIENT,
                budget.getOwner().getId()
        );
        resendEmailService.sendBudgetNotification(
                budget.getOwner().getDisplayName(),
                ownerEmail,
                budget.getTitle(),
                budget.getVessel().getName(),
                budget.getAmount(),
                budget.getCurrency(),
                clientHasAccount
        );
    }

    private void notifyCommercialsAboutClientDecision(Budget budget, BudgetStatus nextStatus) {
        List<Worker> activeCommercials = workerRepository.findByRoleAndActiveTrueOrderByFullNameAsc(Role.COMERCIAL);
        Map<Long, Worker> recipients = new LinkedHashMap<>();
        for (Worker worker : activeCommercials) {
            recipients.put(worker.getId(), worker);
        }

        Worker creator = budget.getCreatedByWorker();
        if (creator != null && creator.isActive() && creator.getRole() == Role.ADMIN) {
            recipients.putIfAbsent(creator.getId(), creator);
        }

        if (recipients.isEmpty()) {
            return;
        }

        String statusLabel = nextStatus == BudgetStatus.ACCEPTED ? "Aceptado" : "Rechazado";
        String clientName = budget.getOwner().getDisplayName();
        String vesselName = budget.getVessel().getName();
        String title = "Presupuesto " + statusLabel.toLowerCase(Locale.ROOT);
        String message = buildCommercialDecisionMessage(budget, statusLabel);

        notificationService.notifyWorkers(
                new LinkedHashSet<>(recipients.keySet()),
                title,
                message,
                "PRESUPUESTOS",
                nextStatus == BudgetStatus.ACCEPTED ? NotificationType.SUCCESS : NotificationType.WARNING
        );

        for (Worker recipient : recipients.values()) {
            try {
                resendEmailService.sendBudgetDecisionNotification(
                        recipient.getFullName(),
                        recipient.getEmail(),
                        clientName,
                        vesselName,
                        budget.getTitle(),
                        statusLabel,
                        budget.getClientObservations()
                );
            } catch (RuntimeException exception) {
                log.warn(
                        "No se pudo enviar el email al comercial sobre la decision del presupuesto. budgetId={}, workerId={}",
                        budget.getId(),
                        recipient.getId(),
                        exception
                );
            }
        }
    }

    private String buildCommercialDecisionMessage(Budget budget, String statusLabel) {
        String base = budget.getOwner().getDisplayName()
                + " ha "
                + statusLabel.toLowerCase(Locale.ROOT)
                + " el presupuesto "
                + budget.getTitle()
                + ".";
        String observations = inputSanitizer.optionalText(budget.getClientObservations(), 160);
        if (observations == null || observations.isBlank()) {
            return base;
        }
        return base + " Observaciones: " + observations;
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

    private Vessel findOrCreatePlaceholderVessel(Owner owner) {
        Long ownerId = owner.getId();
        return vesselRepository.findByOwnerId(ownerId).stream()
                .filter(this::isPlaceholderVessel)
                .findFirst()
                .orElseGet(() -> {
                    Vessel placeholder = new Vessel();
                    placeholder.setOwner(owner);
                    placeholder.setName("Embarcacion pendiente de registrar");
                    placeholder.setRegistrationNumber(
                            buildPlaceholderRegistrationNumber(ownerId, "PENDIENTE")
                    );
                    return vesselRepository.save(placeholder);
                });
    }

    private boolean isPlaceholderVessel(Vessel vessel) {
        String registrationNumber = vessel.getRegistrationNumber();
        return registrationNumber != null
                && registrationNumber.toUpperCase(Locale.ROOT).startsWith("TMP-");
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
        boolean clientHasAccount = workerRepository.existsByRoleAndOwner_Id(
                Role.CLIENT,
                budget.getOwner().getId()
        );
        return toDto(budget, clientHasAccount);
    }

    private List<BudgetDto> toDtos(List<Budget> budgets) {
        if (budgets.isEmpty()) {
            return List.of();
        }
        Set<Long> ownerIds = budgets.stream()
                .map(budget -> budget.getOwner().getId())
                .collect(java.util.stream.Collectors.toSet());
        Set<Long> clientOwnerIds = findClientOwnerIds(ownerIds);
        return budgets.stream()
                .map(budget -> toDto(budget, clientOwnerIds.contains(budget.getOwner().getId())))
                .toList();
    }

    private Set<Long> findClientOwnerIds(Collection<Long> ownerIds) {
        if (ownerIds.isEmpty()) {
            return Set.of();
        }
        return workerRepository.findOwnerIdsByRoleAndOwnerIdIn(Role.CLIENT, ownerIds);
    }

    private BudgetDto toDto(Budget budget, boolean clientHasAccount) {
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
