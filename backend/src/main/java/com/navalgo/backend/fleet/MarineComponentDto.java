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
        long installedCount
) {
    public static MarineComponentDto from(MarineComponent component, long installedCount) {
        return new MarineComponentDto(
                component.getId(),
                component.getType(),
                component.getName(),
                component.getManufacturer(),
                component.getModel(),
                component.getTemplates().stream().map(template -> template.getId()).toList(),
                component.getTemplates().stream().map(template -> template.getName()).toList(),
                installedCount
        );
    }
}
