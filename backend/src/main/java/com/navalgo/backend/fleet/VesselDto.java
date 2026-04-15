package com.navalgo.backend.fleet;

public record VesselDto(
        Long id,
        String name,
        String registrationNumber,
        String model,
        Integer engineCount,
    java.util.List<String> engineLabels,
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
                vessel.getLengthMeters(),
                vessel.getOwner().getId(),
                vessel.getOwner().getDisplayName()
        );
    }
}
