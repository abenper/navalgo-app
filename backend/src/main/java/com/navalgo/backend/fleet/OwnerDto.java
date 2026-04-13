package com.navalgo.backend.fleet;

public record OwnerDto(
        Long id,
        OwnerType type,
        String displayName,
        String documentId,
        String phone,
        String email,
        Long companyId
) {
    public static OwnerDto from(Owner owner) {
        return new OwnerDto(
                owner.getId(),
                owner.getType(),
                owner.getDisplayName(),
                owner.getDocumentId(),
                owner.getPhone(),
                owner.getEmail(),
                owner.getCompany() != null ? owner.getCompany().getId() : null
        );
    }
}
