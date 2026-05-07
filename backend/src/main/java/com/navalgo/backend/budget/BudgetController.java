package com.navalgo.backend.budget;

import com.navalgo.backend.fleet.Owner;
import com.navalgo.backend.fleet.OwnerRepository;
import com.navalgo.backend.fleet.Vessel;
import com.navalgo.backend.fleet.VesselRepository;
import jakarta.persistence.EntityNotFoundException;
import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.util.List;

@RestController
@RequestMapping("/api/budgets")
public class BudgetController {

    private final BudgetService budgetService;
    private final BudgetMediaService budgetMediaService;
    private final OwnerRepository ownerRepository;
    private final VesselRepository vesselRepository;

    public BudgetController(BudgetService budgetService,
                            BudgetMediaService budgetMediaService,
                            OwnerRepository ownerRepository,
                            VesselRepository vesselRepository) {
        this.budgetService = budgetService;
        this.budgetMediaService = budgetMediaService;
        this.ownerRepository = ownerRepository;
        this.vesselRepository = vesselRepository;
    }

    @GetMapping
    @PreAuthorize("hasAnyRole('ADMIN','COMERCIAL')")
    public ResponseEntity<List<BudgetDto>> list() {
        return ResponseEntity.ok(budgetService.findAll());
    }

    @PostMapping
    @PreAuthorize("hasAnyRole('ADMIN','COMERCIAL')")
    public ResponseEntity<BudgetDto> create(@RequestBody @Valid CreateBudgetRequest request,
                                            Authentication authentication) {
        return ResponseEntity.ok(budgetService.create(request, authentication.getName()));
    }

    @PatchMapping("/{id}/status")
    @PreAuthorize("hasAnyRole('ADMIN','COMERCIAL')")
    public ResponseEntity<BudgetDto> updateStatus(@PathVariable Long id,
                                                  @RequestBody @Valid UpdateBudgetStatusRequest request,
                                                  Authentication authentication) {
        return ResponseEntity.ok(budgetService.updateStatus(id, request, authentication.getName()));
    }

    @PostMapping(value = "/uploads", consumes = "multipart/form-data")
    @PreAuthorize("hasAnyRole('ADMIN','COMERCIAL')")
    public ResponseEntity<UploadedBudgetDocumentDto> uploadPdf(@RequestParam("file") MultipartFile file,
                                                               @RequestParam Long ownerId,
                                                               @RequestParam Long vesselId) {
        Owner owner = ownerRepository.findById(ownerId)
                .orElseThrow(() -> new EntityNotFoundException("Cliente no encontrado"));
        Vessel vessel = vesselRepository.findById(vesselId)
                .orElseThrow(() -> new EntityNotFoundException("Embarcacion no encontrada"));
        if (!vessel.getOwner().getId().equals(owner.getId())) {
            throw new IllegalArgumentException("La embarcacion seleccionada no pertenece a ese cliente");
        }
        return ResponseEntity.ok(
                budgetMediaService.uploadBudgetPdf(file, owner.getDisplayName(), vessel.getName())
        );
    }
}
