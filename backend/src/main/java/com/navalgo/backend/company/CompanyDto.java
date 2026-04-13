package com.navalgo.backend.company;

public record CompanyDto(
        Long id,
        String name,
        String taxId,
        String phone,
        String email,
        String address
) {
    public static CompanyDto from(Company company) {
        return new CompanyDto(
                company.getId(),
                company.getName(),
                company.getTaxId(),
                company.getPhone(),
                company.getEmail(),
                company.getAddress()
        );
    }
}
