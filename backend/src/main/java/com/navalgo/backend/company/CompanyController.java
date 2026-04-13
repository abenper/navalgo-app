package com.navalgo.backend.company;

import jakarta.persistence.EntityNotFoundException;
import jakarta.validation.Valid;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/companies")
public class CompanyController {

    private final CompanyRepository repository;

    public CompanyController(CompanyRepository repository) {
        this.repository = repository;
    }

    @GetMapping
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<List<CompanyDto>> list() {
        return ResponseEntity.ok(repository.findAll().stream().map(CompanyDto::from).toList());
    }

    @PostMapping
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<CompanyDto> create(@RequestBody @Valid CreateCompanyRequest request) {
        Company company = new Company();
        company.setName(request.name());
        company.setTaxId(request.taxId());
        company.setPhone(request.phone());
        company.setEmail(request.email());
        company.setAddress(request.address());
        return ResponseEntity.ok(CompanyDto.from(repository.save(company)));
    }

    @GetMapping("/{id}")
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<CompanyDto> getById(@PathVariable Long id) {
        Company company = repository.findById(id).orElseThrow(() -> new EntityNotFoundException("Empresa no encontrada"));
        return ResponseEntity.ok(CompanyDto.from(company));
    }
}
