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
        Owner owner = new Owner();
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

        return ResponseEntity.ok(OwnerDto.from(ownerRepository.save(owner)));
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
        Owner owner = ownerRepository.findById(request.ownerId())
                .orElseThrow(() -> new EntityNotFoundException("Propietario no encontrado"));

        Vessel vessel = new Vessel();
        vessel.setName(request.name());
        vessel.setRegistrationNumber(request.registrationNumber());
        vessel.setModel(request.model());
        vessel.setEngineCount(request.engineCount());
        vessel.setLengthMeters(request.lengthMeters());
        vessel.setOwner(owner);

        return ResponseEntity.ok(VesselDto.from(vesselRepository.save(vessel)));
    }
}
