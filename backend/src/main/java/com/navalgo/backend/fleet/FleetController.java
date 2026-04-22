package com.navalgo.backend.fleet;

import com.navalgo.backend.common.InputSanitizer;
import com.navalgo.backend.company.Company;
import com.navalgo.backend.company.CompanyRepository;
import com.navalgo.backend.workorder.EngineHourLog;
import com.navalgo.backend.workorder.EngineHourSummaryDto;
import com.navalgo.backend.workorder.WorkOrder;
import com.navalgo.backend.workorder.WorkOrderRepository;
import jakarta.persistence.EntityNotFoundException;
import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/fleet")
@Transactional(readOnly = true)
public class FleetController {

    private final OwnerRepository ownerRepository;
    private final VesselRepository vesselRepository;
    private final CompanyRepository companyRepository;
    private final WorkOrderRepository workOrderRepository;
    private final InputSanitizer inputSanitizer;

    public FleetController(OwnerRepository ownerRepository,
                           VesselRepository vesselRepository,
                           CompanyRepository companyRepository,
                           WorkOrderRepository workOrderRepository,
                           InputSanitizer inputSanitizer) {
        this.ownerRepository = ownerRepository;
        this.vesselRepository = vesselRepository;
        this.companyRepository = companyRepository;
        this.workOrderRepository = workOrderRepository;
        this.inputSanitizer = inputSanitizer;
    }

    @GetMapping("/owners")
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<List<OwnerDto>> listOwners() {
        return ResponseEntity.ok(ownerRepository.findAll().stream().map(OwnerDto::from).toList());
    }

    @PostMapping("/owners")
    @PreAuthorize("hasRole('ADMIN')")
    @Transactional
    public ResponseEntity<OwnerDto> createOwner(@RequestBody @Valid CreateOwnerRequest request) {
        return ResponseEntity.ok(OwnerDto.from(ownerRepository.save(buildOwnerFromRequest(new Owner(), request))));
    }

    @PutMapping("/owners/{id}")
    @PreAuthorize("hasRole('ADMIN')")
    @Transactional
    public ResponseEntity<OwnerDto> updateOwner(@PathVariable Long id,
                                                @RequestBody @Valid UpdateOwnerRequest request) {
        Owner owner = ownerRepository.findById(id)
                .orElseThrow(() -> new EntityNotFoundException("Propietario no encontrado"));

        owner.setType(request.type());
        owner.setDisplayName(inputSanitizer.requiredText(request.displayName(), "El nombre del propietario", 255));
        owner.setDocumentId(inputSanitizer.requiredText(request.documentId(), "El documento", 255));
        owner.setPhone(inputSanitizer.optionalText(request.phone(), 255));
        owner.setEmail(request.email() == null ? null : inputSanitizer.email(request.email()));

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
    @PreAuthorize("hasRole('ADMIN')")
    @Transactional
    public ResponseEntity<Void> deleteOwner(@PathVariable Long id) {
        if (!ownerRepository.existsById(id)) {
            throw new EntityNotFoundException("Propietario no encontrado");
        }
        if (!vesselRepository.findByOwnerId(id).isEmpty()) {
            throw new IllegalArgumentException("No se puede borrar un propietario con embarcaciones asociadas");
        }
        ownerRepository.deleteById(id);
        return ResponseEntity.noContent().build();
    }

    private Owner buildOwnerFromRequest(Owner owner, CreateOwnerRequest request) {
        owner.setType(request.type());
        owner.setDisplayName(inputSanitizer.requiredText(request.displayName(), "El nombre del propietario", 255));
        owner.setDocumentId(inputSanitizer.requiredText(request.documentId(), "El documento", 255));
        owner.setPhone(inputSanitizer.optionalText(request.phone(), 255));
        owner.setEmail(request.email() == null ? null : inputSanitizer.email(request.email()));

        if (request.companyId() != null) {
            Company company = companyRepository.findById(request.companyId())
                    .orElseThrow(() -> new EntityNotFoundException("Empresa no encontrada"));
            owner.setCompany(company);
        }
        return owner;
    }

    @GetMapping("/vessels")
    @PreAuthorize("hasAnyRole('ADMIN','WORKER')")
    public ResponseEntity<List<VesselDto>> listVessels(@RequestParam(required = false) Long ownerId) {
        List<Vessel> vessels = ownerId == null
                ? vesselRepository.findAll()
                : vesselRepository.findByOwnerId(ownerId);
        return ResponseEntity.ok(vessels.stream().map(VesselDto::from).toList());
    }

    @PostMapping("/vessels")
    @PreAuthorize("hasRole('ADMIN')")
    @Transactional
    public ResponseEntity<VesselDto> createVessel(@RequestBody @Valid CreateVesselRequest request) {
        return ResponseEntity.ok(VesselDto.from(vesselRepository.save(buildVesselFromCreateRequest(new Vessel(), request))));
    }

    @PutMapping("/vessels/{id}")
    @PreAuthorize("hasRole('ADMIN')")
    @Transactional
    public ResponseEntity<VesselDto> updateVessel(@PathVariable Long id,
                                                  @RequestBody @Valid UpdateVesselRequest request) {
        Vessel vessel = vesselRepository.findById(id)
                .orElseThrow(() -> new EntityNotFoundException("Embarcacion no encontrada"));

        Owner owner = ownerRepository.findById(request.ownerId())
                .orElseThrow(() -> new EntityNotFoundException("Propietario no encontrado"));

        List<String> engineLabels = normalizeEngineLabels(request.engineLabels(), request.engineCount());
        vessel.setName(inputSanitizer.requiredText(request.name(), "El nombre de la embarcacion", 255));
        vessel.setRegistrationNumber(inputSanitizer.requiredText(request.registrationNumber(), "La matricula", 255));
        vessel.setModel(inputSanitizer.optionalText(request.model(), 255));
        vessel.setEngineCount(engineLabels.isEmpty() ? request.engineCount() : engineLabels.size());
        vessel.setEngineLabels(engineLabels);
        vessel.setEngineSerialNumber(inputSanitizer.optionalText(request.engineSerialNumber(), 255));
        vessel.setLengthMeters(request.lengthMeters());
        vessel.setOwner(owner);

        return ResponseEntity.ok(VesselDto.from(vesselRepository.save(vessel)));
    }

    @DeleteMapping("/vessels/{id}")
    @PreAuthorize("hasRole('ADMIN')")
    @Transactional
    public ResponseEntity<Void> deleteVessel(@PathVariable Long id) {
        if (!vesselRepository.existsById(id)) {
            throw new EntityNotFoundException("Embarcacion no encontrada");
        }
        vesselRepository.deleteById(id);
        return ResponseEntity.noContent().build();
    }

    @GetMapping("/vessels/{vesselId}/last-engine-hours")
    @PreAuthorize("hasRole('ADMIN')")
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

    private Vessel buildVesselFromCreateRequest(Vessel vessel, CreateVesselRequest request) {
        Owner owner = ownerRepository.findById(request.ownerId())
                .orElseThrow(() -> new EntityNotFoundException("Propietario no encontrado"));

        List<String> engineLabels = normalizeEngineLabels(request.engineLabels(), request.engineCount());

        vessel.setName(inputSanitizer.requiredText(request.name(), "El nombre de la embarcacion", 255));
        vessel.setRegistrationNumber(inputSanitizer.requiredText(request.registrationNumber(), "La matricula", 255));
        vessel.setModel(inputSanitizer.optionalText(request.model(), 255));
        vessel.setEngineCount(engineLabels.isEmpty() ? request.engineCount() : engineLabels.size());
        vessel.setEngineLabels(engineLabels);
        vessel.setEngineSerialNumber(inputSanitizer.optionalText(request.engineSerialNumber(), 255));
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
}
