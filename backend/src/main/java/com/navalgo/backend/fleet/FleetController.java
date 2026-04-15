package com.navalgo.backend.fleet;

import com.navalgo.backend.company.Company;
import com.navalgo.backend.company.CompanyRepository;
import jakarta.persistence.EntityNotFoundException;
import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/fleet")
@Transactional(readOnly = true)
public class FleetController {

    private final OwnerRepository ownerRepository;
    private final VesselRepository vesselRepository;
    private final CompanyRepository companyRepository;

    public FleetController(OwnerRepository ownerRepository,
                           VesselRepository vesselRepository,
                           CompanyRepository companyRepository) {
        this.ownerRepository = ownerRepository;
        this.vesselRepository = vesselRepository;
        this.companyRepository = companyRepository;
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
        owner.setDisplayName(request.displayName());
        owner.setDocumentId(request.documentId());
        owner.setPhone(request.phone());
        owner.setEmail(request.email());

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
        owner.setDisplayName(request.displayName());
        owner.setDocumentId(request.documentId());
        owner.setPhone(request.phone());
        owner.setEmail(request.email());

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
        vessel.setName(request.name());
        vessel.setRegistrationNumber(request.registrationNumber());
        vessel.setModel(request.model());
        vessel.setEngineCount(engineLabels.isEmpty() ? request.engineCount() : engineLabels.size());
        vessel.setEngineLabels(engineLabels);
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

    private Vessel buildVesselFromCreateRequest(Vessel vessel, CreateVesselRequest request) {
        Owner owner = ownerRepository.findById(request.ownerId())
                .orElseThrow(() -> new EntityNotFoundException("Propietario no encontrado"));

        List<String> engineLabels = normalizeEngineLabels(request.engineLabels(), request.engineCount());

        vessel.setName(request.name());
        vessel.setRegistrationNumber(request.registrationNumber());
        vessel.setModel(request.model());
        vessel.setEngineCount(engineLabels.isEmpty() ? request.engineCount() : engineLabels.size());
        vessel.setEngineLabels(engineLabels);
        vessel.setLengthMeters(request.lengthMeters());
        vessel.setOwner(owner);

        return vessel;
    }

    private List<String> normalizeEngineLabels(List<String> engineLabels, Integer engineCount) {
        if (engineLabels == null || engineLabels.isEmpty()) {
            return List.of();
        }

        List<String> normalized = engineLabels.stream()
                .map(label -> label == null ? "" : label.trim())
                .filter(label -> !label.isEmpty())
                .toList();

        if (engineCount != null && engineCount > 0 && normalized.size() != engineCount) {
            throw new IllegalArgumentException("La cantidad de motores no coincide con las posiciones indicadas");
        }

        return normalized;
    }
}
