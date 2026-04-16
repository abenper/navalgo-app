package com.navalgo.backend.company;

import com.navalgo.backend.common.InputSanitizer;
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
    private final InputSanitizer inputSanitizer;

    public CompanyController(CompanyRepository repository, InputSanitizer inputSanitizer) {
        this.repository = repository;
        this.inputSanitizer = inputSanitizer;
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
        company.setName(inputSanitizer.requiredText(request.name(), "El nombre", 255));
        company.setTaxId(inputSanitizer.requiredText(request.taxId(), "El CIF/NIF", 255));
        company.setPhone(inputSanitizer.optionalText(request.phone(), 255));
        company.setEmail(request.email() == null ? null : inputSanitizer.email(request.email()));
        company.setAddress(inputSanitizer.optionalText(request.address(), 255));
        return ResponseEntity.ok(CompanyDto.from(repository.save(company)));
    }

    @GetMapping("/{id}")
    @PreAuthorize("hasRole('ADMIN')")
    public ResponseEntity<CompanyDto> getById(@PathVariable Long id) {
        Company company = repository.findById(id).orElseThrow(() -> new EntityNotFoundException("Empresa no encontrada"));
        return ResponseEntity.ok(CompanyDto.from(company));
    }
}
