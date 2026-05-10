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
    private final BudgetEventRepository budgetEventRepository;
    private final OwnerRepository ownerRepository;
    private final VesselRepository vesselRepository;
    private final WorkerRepository workerRepository;
    private final InputSanitizer inputSanitizer;
    private final ResendEmailService resendEmailService;
    private final NotificationService notificationService;

    public BudgetService(BudgetRepository budgetRepository,
                         BudgetEventRepository budgetEventRepository,
                         OwnerRepository ownerRepository,
                         VesselRepository vesselRepository,
                         WorkerRepository workerRepository,
                         InputSanitizer inputSanitizer,
                         ResendEmailService resendEmailService,
                         NotificationService notificationService) {
        this.budgetRepository = budgetRepository;
        this.budgetEventRepository = budgetEventRepository;
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
        Budget originBudget = resolveRejectedOriginBudget(request.originBudgetId());
        BudgetTarget target = resolveBudgetTarget(
                request.ownerId(),
                request.contactEmail(),
                request.newClientName()
        );

        Budget budget = new Budget();
        budget.setOwner(target.owner());
        budget.setVessel(target.vessel());
        budget.setCreatedByWorker(current);
        budget.setOriginBudget(originBudget);
        budget.setTitle(inputSanitizer.requiredText(request.title(), "El titulo del presupuesto", 255));
        budget.setDescription(inputSanitizer.optionalText(request.description(), 3000));
        budget.setAmount(request.amount());
        budget.setCurrency(normalizeCurrency(request.currency()));
        budget.setPdfUrl(inputSanitizer.optionalUrl(request.pdfUrl(), 2000));
        budget.setStatus(BudgetStatus.DRAFT);
        budget.setCreatedAt(Instant.now());
        budget.setUpdatedAt(Instant.now());
        Budget savedBudget = budgetRepository.save(budget);
        recordEvent(savedBudget, BudgetEventType.CREATED, current, "Borrador creado.");
        if (originBudget != null) {
            recordEvent(
                    savedBudget,
                    BudgetEventType.REISSUED,
                    current,
                    "Nueva oferta creada a partir del presupuesto rechazado anterior."
            );
            recordEvent(
                    originBudget,
                    BudgetEventType.REISSUED,
                    current,
                    "Se ha creado una nueva oferta en borrador para este rechazo."
            );
        }
        return toDto(savedBudget);
    }

    @Transactional
    public BudgetDto reissue(Long budgetId, String currentUserEmail) {
        Worker current = requireCommercialOrAdmin(currentUserEmail);
        Budget rejectedBudget = budgetRepository.findById(budgetId)
                .orElseThrow(() -> new EntityNotFoundException("Presupuesto no encontrado"));

        if (rejectedBudget.getStatus() != BudgetStatus.REJECTED) {
            throw new IllegalArgumentException("Solo se puede rehacer una oferta rechazada");
        }

        Budget newBudget = new Budget();
        newBudget.setOwner(rejectedBudget.getOwner());
        newBudget.setVessel(rejectedBudget.getVessel());
        newBudget.setCreatedByWorker(current);
        newBudget.setOriginBudget(rejectedBudget);
        newBudget.setTitle(rejectedBudget.getTitle());
        newBudget.setDescription(rejectedBudget.getDescription());
        newBudget.setAmount(rejectedBudget.getAmount());
        newBudget.setCurrency(rejectedBudget.getCurrency());
        newBudget.setPdfUrl(rejectedBudget.getPdfUrl());
        newBudget.setStatus(BudgetStatus.DRAFT);
        newBudget.setClientObservations(null);
        newBudget.setSentAt(null);
        newBudget.setClientDecidedAt(null);
        newBudget.setCreatedAt(Instant.now());
        newBudget.setUpdatedAt(Instant.now());

        Budget savedBudget = budgetRepository.save(newBudget);
        recordEvent(
                savedBudget,
                BudgetEventType.CREATED,
                current,
                "Borrador creado."
        );
        recordEvent(
                savedBudget,
                BudgetEventType.REISSUED,
                current,
                "Nueva oferta creada a partir del presupuesto rechazado anterior."
        );
        recordEvent(
                rejectedBudget,
                BudgetEventType.REISSUED,
                current,
                "Se ha generado una nueva oferta en borrador para este presupuesto rechazado."
        );
        return toDto(savedBudget);
    }

    @Transactional
    public BudgetDto updateDraft(Long budgetId,
                                 UpdateBudgetDraftRequest request,
                                 String currentUserEmail) {
        Worker current = requireCommercialOrAdmin(currentUserEmail);
        Budget budget = budgetRepository.findById(budgetId)
                .orElseThrow(() -> new EntityNotFoundException("Presupuesto no encontrado"));

        if (budget.getStatus() != BudgetStatus.DRAFT) {
            throw new IllegalArgumentException("Solo se pueden editar presupuestos en borrador");
        }

        Owner previousOwner = budget.getOwner();
        String previousEmail = previousOwner.getEmail();
        String previousTitle = budget.getTitle();
        String previousDescription = budget.getDescription();
        java.math.BigDecimal previousAmount = budget.getAmount();
        String previousCurrency = budget.getCurrency();
        String previousPdfUrl = budget.getPdfUrl();

        BudgetTarget target = resolveBudgetTarget(
                request.ownerId(),
                request.contactEmail(),
                request.newClientName()
        );

        budget.setOwner(target.owner());
        budget.setVessel(target.vessel());
        budget.setTitle(inputSanitizer.requiredText(request.title(), "El titulo del presupuesto", 255));
        budget.setDescription(inputSanitizer.optionalText(request.description(), 3000));
        budget.setAmount(request.amount());
        budget.setCurrency(normalizeCurrency(request.currency()));
        budget.setPdfUrl(inputSanitizer.optionalUrl(request.pdfUrl(), 2000));
        budget.setUpdatedAt(Instant.now());

        Budget savedBudget = budgetRepository.save(budget);
        recordEvent(
                savedBudget,
                BudgetEventType.UPDATED,
                current,
                buildDraftUpdatedNote(
                        previousOwner,
                        previousEmail,
                        previousTitle,
                        previousDescription,
                        previousAmount,
                        previousCurrency,
                        previousPdfUrl,
                        savedBudget
                )
        );
        return toDto(savedBudget);
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
        Budget savedBudget = budgetRepository.save(budget);
        recordEvent(
                savedBudget,
                BudgetEventType.VESSEL_LINKED,
                current,
                "Presupuesto vinculado a la embarcación " + vessel.getName() + "."
        );
        return toDto(savedBudget);
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
            budget.setClientDecidedAt(null);
            sendBudgetEmail(budget);
            recordEvent(budget, BudgetEventType.SENT, current, "Presupuesto enviado al cliente.");
        }

        if (nextStatus == BudgetStatus.ACCEPTED || nextStatus == BudgetStatus.REJECTED) {
            budget.setClientDecidedAt(Instant.now());
        }

        if (nextStatus == BudgetStatus.ACCEPTED && previousStatus != BudgetStatus.ACCEPTED) {
            recordEvent(
                    budget,
                    BudgetEventType.ACCEPTED,
                    current,
                    budget.getClientObservations()
            );
        } else if (nextStatus == BudgetStatus.REJECTED && previousStatus != BudgetStatus.REJECTED) {
            recordEvent(
                    budget,
                    BudgetEventType.REJECTED,
                    current,
                    budget.getClientObservations()
            );
        } else if (nextStatus == BudgetStatus.CANCELLED && previousStatus != BudgetStatus.CANCELLED) {
            recordEvent(budget, BudgetEventType.CANCELLED, current, "Presupuesto cancelado.");
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
        boolean clientHasAccount = workerRepository.existsByRoleAndOwner_IdAndActiveTrue(
                Role.CLIENT,
                budget.getOwner().getId()
        );
        resendEmailService.sendBudgetNotification(
                budget.getOwner().getDisplayName(),
                ownerEmail,
                budget.getTitle(),
                resolveBudgetEmailVesselName(budget.getVessel()),
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

    private BudgetTarget resolveBudgetTarget(Long ownerId,
                                             String contactEmail,
                                             String newClientName) {
        Owner owner;
        if (ownerId != null) {
            owner = ownerRepository.findById(ownerId)
                    .orElseThrow(() -> new EntityNotFoundException("Cliente no encontrado"));

            String normalizedContactEmail = inputSanitizer.email(contactEmail);
            if (normalizedContactEmail != null && !normalizedContactEmail.isBlank()) {
                ensureOwnerEmailAvailable(normalizedContactEmail, owner.getId());
                owner.setEmail(normalizedContactEmail);
                owner = ownerRepository.save(owner);
            }
        } else {
            String email = inputSanitizer.email(contactEmail);
            if (email == null || email.isBlank()) {
                throw new IllegalArgumentException("Debe proporcionar un correo electronico valido");
            }

            owner = resolveOwnerByEmail(email).orElseGet(() -> {
                String name = newClientName;
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
        }

        Vessel vessel = findOrCreatePlaceholderVessel(owner);
        return new BudgetTarget(owner, vessel);
    }

    private String buildDraftUpdatedNote(Owner previousOwner,
                                         String previousEmail,
                                         String previousTitle,
                                         String previousDescription,
                                         java.math.BigDecimal previousAmount,
                                         String previousCurrency,
                                         String previousPdfUrl,
                                         Budget updatedBudget) {
        List<String> changes = new java.util.ArrayList<>();
        if (!previousOwner.getId().equals(updatedBudget.getOwner().getId())) {
            changes.add("cliente");
        }
        if (!java.util.Objects.equals(previousEmail, updatedBudget.getOwner().getEmail())) {
            changes.add("correo");
        }
        if (!java.util.Objects.equals(previousTitle, updatedBudget.getTitle())) {
            changes.add("titulo");
        }
        if (!java.util.Objects.equals(previousDescription, updatedBudget.getDescription())) {
            changes.add("descripcion");
        }
        if (!java.util.Objects.equals(previousAmount, updatedBudget.getAmount())
                || !java.util.Objects.equals(previousCurrency, updatedBudget.getCurrency())) {
            changes.add("importe");
        }
        if (!java.util.Objects.equals(previousPdfUrl, updatedBudget.getPdfUrl())) {
            changes.add("PDF");
        }

        if (changes.isEmpty()) {
            return "Borrador revisado sin cambios visibles.";
        }
        return "Borrador actualizado: " + String.join(", ", changes) + ".";
    }

    private String normalizeCurrency(String currency) {
        String normalized = inputSanitizer.optionalText(currency, 3);
        if (normalized == null || normalized.isBlank()) {
            return "EUR";
        }
        return normalized.toUpperCase(Locale.ROOT);
    }

    private String resolveBudgetEmailVesselName(Vessel vessel) {
        if (vessel == null || isPlaceholderVessel(vessel)) {
            return null;
        }
        return vessel.getName();
    }

    private Budget resolveRejectedOriginBudget(Long originBudgetId) {
        if (originBudgetId == null) {
            return null;
        }
        Budget originBudget = budgetRepository.findById(originBudgetId)
                .orElseThrow(() -> new EntityNotFoundException("Presupuesto origen no encontrado"));
        if (originBudget.getStatus() != BudgetStatus.REJECTED) {
            throw new IllegalArgumentException("Solo se puede crear una nueva oferta desde un presupuesto rechazado");
        }
        return originBudget;
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
        boolean clientHasAccount = workerRepository.existsByRoleAndOwner_IdAndActiveTrue(
                Role.CLIENT,
                budget.getOwner().getId()
        );
        return toDto(budget, clientHasAccount, resolveTimeline(budget));
    }

    private List<BudgetDto> toDtos(List<Budget> budgets) {
        if (budgets.isEmpty()) {
            return List.of();
        }
        Set<Long> ownerIds = budgets.stream()
                .map(budget -> budget.getOwner().getId())
                .collect(java.util.stream.Collectors.toSet());
        Set<Long> clientOwnerIds = findClientOwnerIds(ownerIds);
        Map<Long, List<BudgetEventDto>> timelineByBudgetId = resolveTimelineMap(budgets);
        return budgets.stream()
                .map(budget -> toDto(
                        budget,
                        clientOwnerIds.contains(budget.getOwner().getId()),
                        timelineByBudgetId.getOrDefault(budget.getId(), List.of())
                ))
                .toList();
    }

    private Set<Long> findClientOwnerIds(Collection<Long> ownerIds) {
        if (ownerIds.isEmpty()) {
            return Set.of();
        }
        return workerRepository.findOwnerIdsByRoleAndOwnerIdIn(Role.CLIENT, ownerIds);
    }

    private BudgetDto toDto(Budget budget, boolean clientHasAccount, List<BudgetEventDto> timeline) {
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
                budget.getOriginBudget() == null ? null : budget.getOriginBudget().getId(),
                budget.getOriginBudget() == null ? null : budget.getOriginBudget().getTitle(),
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
                budget.getUpdatedAt(),
                timeline
        );
    }

    private void recordEvent(Budget budget,
                             BudgetEventType eventType,
                             Worker actor,
                             String note) {
        BudgetEvent event = new BudgetEvent();
        event.setBudget(budget);
        event.setEventType(eventType);
        event.setActorName(actor.getFullName());
        event.setActorRole(actor.getRole().name());
        event.setNote(inputSanitizer.optionalText(note, 2000));
        event.setCreatedAt(Instant.now());
        budgetEventRepository.save(event);
    }

    private Map<Long, List<BudgetEventDto>> resolveTimelineMap(List<Budget> budgets) {
        if (budgets.isEmpty()) {
            return Map.of();
        }

        List<Long> budgetIds = budgets.stream()
                .map(Budget::getId)
                .toList();
        List<BudgetEvent> events = budgetEventRepository.findByBudgetIdInOrderByBudgetIdAscCreatedAtAscIdAsc(budgetIds);
        Map<Long, List<BudgetEventDto>> grouped = new LinkedHashMap<>();
        for (BudgetEvent event : events) {
            grouped.computeIfAbsent(event.getBudget().getId(), ignored -> new java.util.ArrayList<>())
                    .add(toEventDto(event));
        }

        Map<Long, Budget> budgetById = budgets.stream()
                .collect(java.util.stream.Collectors.toMap(Budget::getId, budget -> budget));
        for (Budget budget : budgets) {
            grouped.computeIfAbsent(budget.getId(), ignored -> buildFallbackTimeline(budget));
        }
        return grouped;
    }

    private List<BudgetEventDto> resolveTimeline(Budget budget) {
        List<BudgetEvent> events = budgetEventRepository.findByBudgetIdOrderByCreatedAtAscIdAsc(budget.getId());
        if (events.isEmpty()) {
            return buildFallbackTimeline(budget);
        }
        return events.stream().map(this::toEventDto).toList();
    }

    private BudgetEventDto toEventDto(BudgetEvent event) {
        return new BudgetEventDto(
                event.getId(),
                event.getEventType().name(),
                event.getActorName(),
                event.getActorRole(),
                event.getNote(),
                event.getCreatedAt()
        );
    }

    private List<BudgetEventDto> buildFallbackTimeline(Budget budget) {
        List<BudgetEventDto> timeline = new java.util.ArrayList<>();
        timeline.add(new BudgetEventDto(
                null,
                BudgetEventType.CREATED.name(),
                budget.getCreatedByWorker().getFullName(),
                budget.getCreatedByWorker().getRole().name(),
                "Borrador creado.",
                budget.getCreatedAt()
        ));
        if (budget.getSentAt() != null) {
            timeline.add(new BudgetEventDto(
                    null,
                    BudgetEventType.SENT.name(),
                    budget.getCreatedByWorker().getFullName(),
                    budget.getCreatedByWorker().getRole().name(),
                    "Presupuesto enviado al cliente.",
                    budget.getSentAt()
            ));
        }
        if (budget.getClientDecidedAt() != null &&
                (budget.getStatus() == BudgetStatus.ACCEPTED || budget.getStatus() == BudgetStatus.REJECTED)) {
            timeline.add(new BudgetEventDto(
                    null,
                    budget.getStatus().name(),
                    budget.getOwner().getDisplayName(),
                    Role.CLIENT.name(),
                    budget.getClientObservations(),
                    budget.getClientDecidedAt()
            ));
        }
        return timeline;
    }
}
