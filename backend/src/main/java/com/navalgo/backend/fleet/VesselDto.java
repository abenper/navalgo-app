package com.navalgo.backend.fleet;

public record VesselDto(
        Long id,
        String name,
        String registrationNumber,
        String model,
        Integer engineCount,
        java.util.List<String> engineLabels,
        java.util.List<String> engineSerialNumbers,
        boolean hasJets,
        java.util.List<String> jetLabels,
        java.util.List<String> jetSerialNumbers,
        boolean hasGearboxes,
        java.util.List<String> gearboxLabels,
        java.util.List<String> gearboxSerialNumbers,
        Double lengthMeters,
        Long ownerId,
        String ownerName
) {
    public static VesselDto from(Vessel vessel) {
        return new VesselDto(
                vessel.getId(),
                vessel.getName(),
                vessel.getRegistrationNumber(),
                vessel.getModel(),
                vessel.getEngineCount(),
                vessel.getEngineLabels(),
                vessel.getEngineSerialNumbers(),
                !vessel.getJetLabels().isEmpty(),
                vessel.getJetLabels(),
                vessel.getJetSerialNumbers(),
                !vessel.getGearboxLabels().isEmpty(),
                vessel.getGearboxLabels(),
                vessel.getGearboxSerialNumbers(),
                vessel.getLengthMeters(),
                vessel.getOwner().getId(),
                vessel.getOwner().getDisplayName()
        );
    }
}
