package com.navalgo.backend.fleet;

import com.navalgo.backend.common.InputSanitizer;
import com.navalgo.backend.common.Role;
import com.navalgo.backend.company.Company;
import com.navalgo.backend.company.CompanyRepository;
import com.navalgo.backend.budget.BudgetRepository;
import com.navalgo.backend.workorder.EngineHourLog;
import com.navalgo.backend.workorder.EngineHourSummaryDto;
import com.navalgo.backend.workorder.WorkOrder;
import com.navalgo.backend.workorder.WorkOrderRepository;
import com.navalgo.backend.worker.Worker;
import com.navalgo.backend.worker.WorkerRepository;
import jakarta.persistence.EntityNotFoundException;
import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;

import java.time.Instant;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Comparator;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;

@RestController
@RequestMapping("/api/fleet")
@Transactional(readOnly = true)
public class FleetController {

    private final OwnerRepository ownerRepository;
    private final VesselRepository vesselRepository;
    private final CompanyRepository companyRepository;
    private final BudgetRepository budgetRepository;
    private final WorkOrderRepository workOrderRepository;
    private final WorkerRepository workerRepository;
    private final InputSanitizer inputSanitizer;

    public FleetController(OwnerRepository ownerRepository,
                           VesselRepository vesselRepository,
                           CompanyRepository companyRepository,
                           BudgetRepository budgetRepository,
                           WorkOrderRepository workOrderRepository,
                           WorkerRepository workerRepository,
                           InputSanitizer inputSanitizer) {
        this.ownerRepository = ownerRepository;
        this.vesselRepository = vesselRepository;
        this.companyRepository = companyRepository;
        this.budgetRepository = budgetRepository;
        this.workOrderRepository = workOrderRepository;
        this.workerRepository = workerRepository;
        this.inputSanitizer = inputSanitizer;
    }

    @GetMapping("/owners")
    @PreAuthorize("hasAnyRole('ADMIN','COMERCIAL','WORKER')")
    public ResponseEntity<List<OwnerDto>> listOwners(Authentication authentication) {
        ensureCanManageFleetCreation(authentication);
        return ResponseEntity.ok(ownerRepository.findAllByArchivedFalseOrderByDisplayNameAsc().stream().map(OwnerDto::from).toList());
    }

    @PostMapping("/owners")
    @PreAuthorize("hasAnyRole('ADMIN','COMERCIAL','WORKER')")
    @Transactional
    public ResponseEntity<OwnerDto> createOwner(@RequestBody @Valid CreateOwnerRequest request,
                                                Authentication authentication) {
        ensureCanManageFleetCreation(authentication);
        return ResponseEntity.ok(OwnerDto.from(ownerRepository.save(buildOwnerFromRequest(new Owner(), request))));
    }

    @PutMapping("/owners/{id}")
    @PreAuthorize("hasAnyRole('ADMIN','COMERCIAL')")
    @Transactional
    public ResponseEntity<OwnerDto> updateOwner(@PathVariable Long id,
                                                @RequestBody @Valid UpdateOwnerRequest request) {
        Owner owner = ownerRepository.findByIdAndArchivedFalse(id)
                .orElseThrow(() -> new EntityNotFoundException("Propietario no encontrado"));

        owner.setType(request.type());
        owner.setDisplayName(inputSanitizer.requiredText(request.displayName(), "El nombre del propietario", 255));
        owner.setDocumentId(inputSanitizer.requiredText(request.documentId(), "El documento", 255));
        owner.setPhone(inputSanitizer.optionalText(request.phone(), 255));
        String normalizedEmail = normalizeOwnerEmail(request.type(), request.email());
        ensureOwnerEmailAvailable(normalizedEmail, owner.getId());
        owner.setEmail(normalizedEmail);

        if (request.companyId() != null) {
            Company company = companyRepository.findById(request.companyId())
                    .orElseThrow(() -> new EntityNotFoundException("Empresa no encontrada"));
            owner.setCompany(company);
        } else {
            owner.setCompany(null);
        }

        return ResponseEntity.ok(OwnerDto.from(ownerRepository.save(owner)));
    }

    @DeleteMapping("/owners/{id}")
    @PreAuthorize("hasAnyRole('ADMIN','COMERCIAL')")
    @Transactional
    public ResponseEntity<Void> deleteOwner(@PathVariable Long id) {
        Owner owner = ownerRepository.findByIdAndArchivedFalse(id)
                .orElseThrow(() -> new EntityNotFoundException("Propietario no encontrado"));

        List<Vessel> activeVessels = vesselRepository.findByOwnerIdAndArchivedFalse(id);
        boolean hasOwnerHistory = workOrderRepository.existsByOwnerId(id) || budgetRepository.existsByOwnerId(id);
        boolean anyVesselHasHistory = activeVessels.stream().anyMatch(vessel ->
                workOrderRepository.existsByVesselId(vessel.getId()) || budgetRepository.existsByVesselId(vessel.getId())
        );

        if (hasOwnerHistory || anyVesselHasHistory) {
            archiveOwner(owner, activeVessels);
            return ResponseEntity.noContent().build();
        }

        for (Vessel vessel : activeVessels) {
            vesselRepository.delete(vessel);
        }
        workerRepository.findByOwner_Id(id).ifPresent(workerRepository::delete);
        ownerRepository.delete(owner);
        return ResponseEntity.noContent().build();
    }

    private Owner buildOwnerFromRequest(Owner owner, CreateOwnerRequest request) {
        owner.setType(request.type());
        owner.setDisplayName(inputSanitizer.requiredText(request.displayName(), "El nombre del propietario", 255));
        owner.setDocumentId(inputSanitizer.requiredText(request.documentId(), "El documento", 255));
        owner.setPhone(inputSanitizer.optionalText(request.phone(), 255));
        String normalizedEmail = normalizeOwnerEmail(request.type(), request.email());
        ensureOwnerEmailAvailable(normalizedEmail, owner.getId());
        owner.setEmail(normalizedEmail);

        if (request.companyId() != null) {
            Company company = companyRepository.findById(request.companyId())
                    .orElseThrow(() -> new EntityNotFoundException("Empresa no encontrada"));
            owner.setCompany(company);
        }
        return owner;
    }

    @GetMapping("/vessels")
    @PreAuthorize("hasAnyRole('ADMIN','COMERCIAL','WORKER')")
    public ResponseEntity<List<VesselDto>> listVessels(@RequestParam(required = false) Long ownerId) {
        List<Vessel> vessels = ownerId == null
                ? vesselRepository.findAllByArchivedFalseOrderByNameAsc()
                : vesselRepository.findByOwnerIdAndArchivedFalseOrderByNameAsc(ownerId);
        return ResponseEntity.ok(vessels.stream().map(VesselDto::from).toList());
    }

    @PostMapping("/vessels")
    @PreAuthorize("hasAnyRole('ADMIN','COMERCIAL','WORKER')")
    @Transactional
    public ResponseEntity<VesselDto> createVessel(@RequestBody @Valid CreateVesselRequest request,
                                                  Authentication authentication) {
        ensureCanManageFleetCreation(authentication);
        return ResponseEntity.ok(VesselDto.from(vesselRepository.save(buildVesselFromCreateRequest(new Vessel(), request))));
    }

    @PutMapping("/vessels/{id}")
    @PreAuthorize("hasAnyRole('ADMIN','COMERCIAL')")
    @Transactional
    public ResponseEntity<VesselDto> updateVessel(@PathVariable Long id,
                                                  @RequestBody @Valid UpdateVesselRequest request) {
        Vessel vessel = vesselRepository.findByIdAndArchivedFalse(id)
                .orElseThrow(() -> new EntityNotFoundException("Embarcacion no encontrada"));

        Owner owner = ownerRepository.findByIdAndArchivedFalse(request.ownerId())
                .orElseThrow(() -> new EntityNotFoundException("Propietario no encontrado"));

        List<String> engineLabels = normalizeEngineLabels(request.engineLabels(), request.engineCount());
        List<String> engineSerialNumbers = normalizeEngineSerialNumbers(
            request.engineSerialNumbers(),
            request.engineCount());
        List<String> jetLabels = resolveAssociatedComponentLabels(engineLabels, request.hasJets(), "jets");
        List<String> jetSerialNumbers = normalizeAssociatedComponentSerialNumbers(
                request.jetSerialNumbers(),
                jetLabels,
                "jets"
        );
        List<String> gearboxLabels = resolveAssociatedComponentLabels(
                engineLabels,
                request.hasGearboxes(),
                "reductoras"
        );
        List<String> gearboxSerialNumbers = normalizeAssociatedComponentSerialNumbers(
                request.gearboxSerialNumbers(),
                gearboxLabels,
                "reductoras"
        );
        vessel.setName(inputSanitizer.requiredText(request.name(), "El nombre de la embarcacion", 255));
        vessel.setRegistrationNumber(inputSanitizer.optionalText(request.registrationNumber(), 255));
        vessel.setModel(inputSanitizer.optionalText(request.model(), 255));
        vessel.setEngineCount(engineLabels.isEmpty() ? request.engineCount() : engineLabels.size());
        vessel.setEngineLabels(engineLabels);
        vessel.setEngineSerialNumbers(engineSerialNumbers);
        vessel.setJetLabels(jetLabels);
        vessel.setJetSerialNumbers(jetSerialNumbers);
        vessel.setGearboxLabels(gearboxLabels);
        vessel.setGearboxSerialNumbers(gearboxSerialNumbers);
        vessel.setLengthMeters(request.lengthMeters());
        vessel.setOwner(owner);

        return ResponseEntity.ok(VesselDto.from(vesselRepository.save(vessel)));
    }

    @DeleteMapping("/vessels/{id}")
    @PreAuthorize("hasAnyRole('ADMIN','COMERCIAL')")
    @Transactional
    public ResponseEntity<Void> deleteVessel(@PathVariable Long id) {
        Vessel vessel = vesselRepository.findByIdAndArchivedFalse(id)
                .orElseThrow(() -> new EntityNotFoundException("Embarcacion no encontrada"));
        if (workOrderRepository.existsByVesselId(id) || budgetRepository.existsByVesselId(id)) {
            archiveVessel(vessel);
            return ResponseEntity.noContent().build();
        }
        vesselRepository.delete(vessel);
        return ResponseEntity.noContent().build();
    }

    @GetMapping("/vessels/{vesselId}/last-engine-hours")
    @PreAuthorize("hasAnyRole('ADMIN','COMERCIAL')")
    public ResponseEntity<List<EngineHourSummaryDto>> lastEngineHours(@PathVariable Long vesselId) {
        if (!vesselRepository.existsById(vesselId)) {
            throw new EntityNotFoundException("Embarcacion no encontrada");
        }
        List<WorkOrder> orders = workOrderRepository.findByVesselIdOrderByCreatedAtDesc(vesselId);
        Map<String, EngineHourSummaryDto> latestByLabel = new LinkedHashMap<>();
        for (WorkOrder wo : orders) {
            for (EngineHourLog log : wo.getEngineHourLogs()) {
                latestByLabel.putIfAbsent(log.getEngineLabel(),
                        new EngineHourSummaryDto(log.getEngineLabel(), log.getHours(), wo.getCreatedAt()));
            }
        }
        return ResponseEntity.ok(new ArrayList<>(latestByLabel.values()));
    }

    @GetMapping("/vessels/{vesselId}/stats")
    @PreAuthorize("hasAnyRole('ADMIN','COMERCIAL')")
    public ResponseEntity<VesselStatsDto> vesselStats(@PathVariable Long vesselId) {
        if (!vesselRepository.existsById(vesselId)) {
            throw new EntityNotFoundException("Embarcacion no encontrada");
        }

        List<WorkOrder> orders = workOrderRepository.findByVesselIdOrderByCreatedAtAsc(vesselId);
        Map<String, List<VesselEngineHourPointDto>> pointsByLabel = new LinkedHashMap<>();
        Map<String, EngineHourSummaryDto> latestByLabel = new LinkedHashMap<>();
        List<VesselWorkOrderMilestoneDto> milestones = new ArrayList<>();
        Integer highestRecordedHour = null;
        java.time.Instant firstRecordedAt = null;
        java.time.Instant lastRecordedAt = null;
        int workOrdersWithEngineHours = 0;

        for (WorkOrder workOrder : orders) {
            List<EngineHourSummaryDto> orderEngineHours = workOrder.getEngineHourLogs().stream()
                    .sorted(Comparator.comparing(EngineHourLog::getEngineLabel, String.CASE_INSENSITIVE_ORDER))
                    .map(log -> new EngineHourSummaryDto(
                            log.getEngineLabel(),
                            log.getHours(),
                            workOrder.getCreatedAt()
                    ))
                    .toList();

            Integer milestoneMaxHours = null;
            if (!orderEngineHours.isEmpty()) {
                workOrdersWithEngineHours += 1;
            }

            for (EngineHourSummaryDto engineHour : orderEngineHours) {
                pointsByLabel.computeIfAbsent(engineHour.engineLabel(), ignored -> new ArrayList<>())
                        .add(new VesselEngineHourPointDto(
                                workOrder.getId(),
                                workOrder.getTitle(),
                                workOrder.getStatus().name(),
                                engineHour.hours(),
                                workOrder.getCreatedAt()
                        ));
                latestByLabel.put(engineHour.engineLabel(), engineHour);

                if (milestoneMaxHours == null || engineHour.hours() > milestoneMaxHours) {
                    milestoneMaxHours = engineHour.hours();
                }
                if (highestRecordedHour == null || engineHour.hours() > highestRecordedHour) {
                    highestRecordedHour = engineHour.hours();
                }
                if (firstRecordedAt == null || workOrder.getCreatedAt().isBefore(firstRecordedAt)) {
                    firstRecordedAt = workOrder.getCreatedAt();
                }
                if (lastRecordedAt == null || workOrder.getCreatedAt().isAfter(lastRecordedAt)) {
                    lastRecordedAt = workOrder.getCreatedAt();
                }
            }

            milestones.add(new VesselWorkOrderMilestoneDto(
                    workOrder.getId(),
                    workOrder.getTitle(),
                    workOrder.getStatus().name(),
                    workOrder.getCreatedAt(),
                    milestoneMaxHours,
                    orderEngineHours
            ));
        }

        List<VesselEngineHourSeriesDto> engineSeries = pointsByLabel.entrySet().stream()
                .map(entry -> new VesselEngineHourSeriesDto(entry.getKey(), List.copyOf(entry.getValue())))
                .toList();

        VesselStatsDto response = new VesselStatsDto(
                vesselId,
                orders.size(),
                workOrdersWithEngineHours,
                firstRecordedAt,
                lastRecordedAt,
                highestRecordedHour,
                new ArrayList<>(latestByLabel.values()),
                engineSeries,
                milestones
        );
        return ResponseEntity.ok(response);
    }

    private Vessel buildVesselFromCreateRequest(Vessel vessel, CreateVesselRequest request) {
        Owner owner = ownerRepository.findByIdAndArchivedFalse(request.ownerId())
                .orElseThrow(() -> new EntityNotFoundException("Propietario no encontrado"));

        List<String> engineLabels = normalizeEngineLabels(request.engineLabels(), request.engineCount());
        List<String> engineSerialNumbers = normalizeEngineSerialNumbers(
            request.engineSerialNumbers(),
            request.engineCount());
        List<String> jetLabels = resolveAssociatedComponentLabels(engineLabels, request.hasJets(), "jets");
        List<String> jetSerialNumbers = normalizeAssociatedComponentSerialNumbers(
                request.jetSerialNumbers(),
                jetLabels,
                "jets"
        );
        List<String> gearboxLabels = resolveAssociatedComponentLabels(
                engineLabels,
                request.hasGearboxes(),
                "reductoras"
        );
        List<String> gearboxSerialNumbers = normalizeAssociatedComponentSerialNumbers(
                request.gearboxSerialNumbers(),
                gearboxLabels,
                "reductoras"
        );

        vessel.setName(inputSanitizer.requiredText(request.name(), "El nombre de la embarcacion", 255));
        vessel.setRegistrationNumber(inputSanitizer.optionalText(request.registrationNumber(), 255));
        vessel.setModel(inputSanitizer.optionalText(request.model(), 255));
        vessel.setEngineCount(engineLabels.isEmpty() ? request.engineCount() : engineLabels.size());
        vessel.setEngineLabels(engineLabels);
        vessel.setEngineSerialNumbers(engineSerialNumbers);
        vessel.setJetLabels(jetLabels);
        vessel.setJetSerialNumbers(jetSerialNumbers);
        vessel.setGearboxLabels(gearboxLabels);
        vessel.setGearboxSerialNumbers(gearboxSerialNumbers);
        vessel.setLengthMeters(request.lengthMeters());
        vessel.setOwner(owner);

        return vessel;
    }

    private List<String> normalizeEngineLabels(List<String> engineLabels, Integer engineCount) {
        if (engineLabels == null || engineLabels.isEmpty()) {
            return List.of();
        }

        List<String> normalized = engineLabels.stream()
            .map(label -> label == null ? "" : inputSanitizer.optionalText(label, 255))
            .map(label -> label == null ? "" : label.trim())
                .filter(label -> !label.isEmpty())
                .toList();

        if (engineCount != null && engineCount > 0 && normalized.size() != engineCount) {
            throw new IllegalArgumentException("La cantidad de motores no coincide con las posiciones indicadas");
        }

        return normalized;
    }

    private void ensureCanManageFleetCreation(Authentication authentication) {
        Worker current = workerRepository.findByEmailIgnoreCase(authentication.getName())
                .orElseThrow(() -> new EntityNotFoundException("Usuario no encontrado"));
        if (current.getRole() == Role.ADMIN || current.getRole() == Role.COMERCIAL) {
            return;
        }
        if (current.getRole() == Role.WORKER && current.isCanEditWorkOrders()) {
            return;
        }
        throw new AccessDeniedException("No tienes permiso para crear clientes o embarcaciones");
    }

    private List<String> normalizeEngineSerialNumbers(List<String> engineSerialNumbers,
                                                      Integer engineCount) {
        if (engineSerialNumbers == null || engineSerialNumbers.isEmpty()) {
            return List.of();
        }

        List<String> normalized = engineSerialNumbers.stream()
                .map(value -> inputSanitizer.optionalText(value, 255))
                .map(value -> value == null ? "" : value.trim())
                .toList();

        if (engineCount != null && engineCount > 0) {
            if (normalized.size() > engineCount) {
                throw new IllegalArgumentException("La cantidad de motores no coincide con los numeros de serie indicados");
            }
            if (normalized.size() < engineCount) {
                List<String> padded = new ArrayList<>(normalized);
                while (padded.size() < engineCount) {
                    padded.add("");
                }
                return padded;
            }
        }

        return normalized;
    }

    private List<String> resolveAssociatedComponentLabels(List<String> engineLabels,
                                                          Boolean enabled,
                                                          String componentName) {
        if (!Boolean.TRUE.equals(enabled)) {
            return List.of();
        }

        if (engineLabels == null || engineLabels.isEmpty()) {
            throw new IllegalArgumentException(
                    "No se pueden configurar " + componentName + " sin motores en posiciones compatibles"
            );
        }

        List<String> eligibleLabels = engineLabels.stream()
                .filter(this::isEligibleAssociatedEngineLabel)
                .toList();

        if (eligibleLabels.isEmpty()) {
            throw new IllegalArgumentException(
                    "Solo se pueden configurar " + componentName
                            + " cuando exista motor central, babor o estribor"
            );
        }

        return eligibleLabels;
    }

    private List<String> normalizeAssociatedComponentSerialNumbers(List<String> serialNumbers,
                                                                   List<String> labels,
                                                                   String componentName) {
        if (labels.isEmpty()) {
            return List.of();
        }

        List<String> normalized = serialNumbers == null
                ? List.of()
                : serialNumbers.stream()
                .map(value -> inputSanitizer.optionalText(value, 255))
                .map(value -> value == null ? "" : value.trim())
                .toList();

        if (normalized.size() > labels.size()) {
            throw new IllegalArgumentException(
                    "La cantidad de numeros de serie no coincide con las posiciones de " + componentName
            );
        }

        if (normalized.size() < labels.size()) {
            List<String> padded = new ArrayList<>(normalized);
            while (padded.size() < labels.size()) {
                padded.add("");
            }
            return padded;
        }

        return normalized;
    }

    private boolean isEligibleAssociatedEngineLabel(String label) {
        String baseLabel = label == null
                ? ""
                : label.replaceAll("\\s+\\d+$", "").trim();
        Set<String> eligibleLabels = new HashSet<>(Arrays.asList("Motor central", "Babor", "Estribor"));
        return eligibleLabels.contains(baseLabel);
    }

    private void ensureOwnerEmailAvailable(String email, Long ownerId) {
        if (email == null || email.isBlank()) {
            return;
        }
        boolean exists = ownerId == null
                ? ownerRepository.existsByEmailIgnoreCaseAndArchivedFalse(email)
                : ownerRepository.existsByEmailIgnoreCaseAndIdNotAndArchivedFalse(email, ownerId);
        if (exists) {
            throw new IllegalArgumentException("Ya existe un cliente con ese correo electronico");
        }
    }

    private String normalizeOwnerEmail(OwnerType ownerType, String email) {
        if (ownerType == OwnerType.COMPANY) {
            return inputSanitizer.optionalEmail(email);
        }
        return inputSanitizer.email(email);
    }

    private void archiveOwner(Owner owner, List<Vessel> activeVessels) {
        owner.setArchived(true);
        owner.setArchivedAt(Instant.now());
        ownerRepository.save(owner);

        for (Vessel vessel : activeVessels) {
            archiveVessel(vessel);
        }

        workerRepository.findByOwner_Id(owner.getId()).ifPresent(worker -> {
            if (worker.getRole() == com.navalgo.backend.common.Role.CLIENT) {
                worker.setActive(false);
                workerRepository.save(worker);
            }
        });
    }

    private void archiveVessel(Vessel vessel) {
        vessel.setArchived(true);
        vessel.setArchivedAt(Instant.now());
        vesselRepository.save(vessel);
    }
}
