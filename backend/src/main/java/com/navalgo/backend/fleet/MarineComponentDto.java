package com.navalgo.backend.fleet;

import java.util.List;

public record MarineComponentDto(
        Long id,
        VesselComponentType type,
        String name,
        String manufacturer,
        String model,
        List<Long> templateIds,
        List<String> templateNames,
        long installedCount,
        List<Installation> installations
) {
    public static MarineComponentDto from(MarineComponent component, List<Installation> installations) {
        List<Installation> safeInstallations = installations == null ? List.of() : installations;
        return new MarineComponentDto(
                component.getId(),
                component.getType(),
                component.getName(),
                component.getManufacturer(),
                component.getModel(),
                component.getTemplates().stream().map(template -> template.getId()).toList(),
                component.getTemplates().stream().map(template -> template.getName()).toList(),
                safeInstallations.size(),
                safeInstallations
        );
    }

    public record Installation(
            Long vesselId,
            String vesselName,
            Long ownerId,
            String ownerName,
            Long vesselComponentId,
            String label,
            String serialNumber,
            Integer currentHours
    ) {
        public static Installation from(VesselComponent component) {
            Vessel vessel = component.getVessel();
            Owner owner = vessel == null ? null : vessel.getOwner();
            return new Installation(
                    vessel == null ? null : vessel.getId(),
                    vessel == null ? null : vessel.getName(),
                    owner == null ? null : owner.getId(),
                    owner == null ? null : owner.getDisplayName(),
                    component.getId(),
                    component.getLabel(),
                    component.getSerialNumber(),
                    component.getCurrentHours()
            );
        }
    }
}
