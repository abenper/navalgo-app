package com.navalgo.backend.budget;

import com.navalgo.backend.common.InputSanitizer;
import com.navalgo.backend.common.Role;
import com.navalgo.backend.fleet.Owner;
import com.navalgo.backend.fleet.OwnerRepository;
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

    @Transactional
    public BudgetDto create(CreateBudgetRequest request, String currentUserEmail) {
        Worker current = requireCommercialOrAdmin(currentUserEmail);
        Owner owner = ownerRepository.findById(request.ownerId())
                .orElseThrow(() -> new EntityNotFoundException("Cliente no encontrado"));
        Vessel vessel = vesselRepository.findById(request.vesselId())
                .orElseThrow(() -> new EntityNotFoundException("Embarcacion no encontrada"));

        if (!vessel.getOwner().getId().equals(owner.getId())) {
            throw new IllegalArgumentException("La embarcacion seleccionada no pertenece a ese cliente");
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
        requireCommercialOrAdmin(currentUserEmail);
        Budget budget = budgetRepository.findById(budgetId)
                .orElseThrow(() -> new EntityNotFoundException("Presupuesto no encontrado"));

        BudgetStatus previousStatus = budget.getStatus();
        BudgetStatus nextStatus = request.status();
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

    private void sendBudgetEmail(Budget budget) {
        String ownerEmail = budget.getOwner().getEmail();
        if (ownerEmail == null || ownerEmail.isBlank()) {
            throw new IllegalArgumentException("El cliente no tiene correo electronico para enviar el presupuesto");
        }
        resendEmailService.sendBudgetNotification(
                budget.getOwner().getDisplayName(),
                ownerEmail,
                budget.getTitle(),
                budget.getVessel().getName(),
                budget.getAmount(),
                budget.getCurrency(),
                budget.getPdfUrl()
        );
    }

    private Worker requireCommercialOrAdmin(String email) {
        Worker worker = workerRepository.findByEmailIgnoreCase(email)
                .orElseThrow(() -> new EntityNotFoundException("Usuario no encontrado"));
        if (!worker.isActive()) {
            throw new AccessDeniedException("Usuario inactivo");
        }
        if (worker.getRole() != Role.ADMIN && worker.getRole() != Role.COMERCIAL) {
            throw new AccessDeniedException("No tienes permiso para gestionar presupuestos");
        }
        return worker;
    }

    private String normalizeCurrency(String currency) {
        String normalized = inputSanitizer.optionalText(currency, 3);
        if (normalized == null || normalized.isBlank()) {
            return "EUR";
        }
        return normalized.toUpperCase(Locale.ROOT);
    }

    private BudgetDto toDto(Budget budget) {
        return new BudgetDto(
                budget.getId(),
                budget.getOwner().getId(),
                budget.getOwner().getDisplayName(),
                budget.getOwner().getEmail(),
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
