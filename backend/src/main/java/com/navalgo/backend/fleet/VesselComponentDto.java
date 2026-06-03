package com.navalgo.backend.fleet;

import java.util.List;

public record VesselComponentDto(
        Long id,
        Long componentId,
        VesselComponentType type,
        String label,
        String manufacturer,
        String model,
        String serialNumber,
        Integer currentHours,
        List<Long> templateIds,
        List<String> templateNames
) {
    public static VesselComponentDto from(VesselComponent component) {
        MarineComponent baseComponent = component.getMarineComponent();
        java.util.Set<com.navalgo.backend.workorder.MaterialChecklistTemplate> templates = baseComponent == null
                ? component.getTemplates()
                : baseComponent.getTemplates();
        return new VesselComponentDto(
                component.getId(),
                baseComponent == null ? null : baseComponent.getId(),
                component.getType(),
                component.getLabel(),
                component.getManufacturer(),
                component.getModel(),
                component.getSerialNumber(),
                component.getCurrentHours(),
                templates.stream()
                        .map(template -> template.getId())
                        .toList(),
                templates.stream()
                        .map(template -> template.getName())
                        .toList()
        );
    }
}
