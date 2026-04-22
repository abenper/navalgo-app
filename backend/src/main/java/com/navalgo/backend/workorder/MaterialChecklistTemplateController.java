package com.navalgo.backend.workorder;

import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/work-order-material-templates")
public class MaterialChecklistTemplateController {

    private final MaterialChecklistTemplateService service;

    public MaterialChecklistTemplateController(MaterialChecklistTemplateService service) {
        this.service = service;
    }

    @GetMapping
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<List<MaterialChecklistTemplateDto>> list() {
        return ResponseEntity.ok(service.findAll());
    }

    @PostMapping
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<MaterialChecklistTemplateDto> create(
            @RequestBody @Valid CreateMaterialChecklistTemplateRequest request
    ) {
        return ResponseEntity.ok(service.create(request));
    }

    @PatchMapping("/{id}")
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<MaterialChecklistTemplateDto> update(
            @PathVariable Long id,
            @RequestBody @Valid CreateMaterialChecklistTemplateRequest request
    ) {
        return ResponseEntity.ok(service.update(id, request));
    }
}