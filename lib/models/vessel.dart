class EngineHourSummary {
  const EngineHourSummary({
    required this.engineLabel,
    required this.hours,
    required this.recordedAt,
  });

  final String engineLabel;
  final int hours;
  final DateTime recordedAt;

  factory EngineHourSummary.fromJson(Map<String, dynamic> json) {
    return EngineHourSummary(
      engineLabel: json['engineLabel'] as String,
      hours: (json['hours'] as num).toInt(),
      recordedAt: DateTime.parse(json['recordedAt'] as String),
    );
  }
}

class Vessel {
  const Vessel({
    required this.id,
    required this.name,
    required this.registrationNumber,
    this.model,
    this.engineCount,
    required this.engineLabels,
    required this.engineSerialNumbers,
    this.lengthMeters,
    required this.ownerId,
    required this.ownerName,
  });

  final int id;
  final String name;
  final String registrationNumber;
  final String? model;
  final int? engineCount;
  final List<String> engineLabels;
  final List<String> engineSerialNumbers;
  final double? lengthMeters;
  final int ownerId;
  final String ownerName;

  factory Vessel.fromJson(Map<String, dynamic> json) {
    return Vessel(
      id: json['id'] as int,
      name: json['name'] as String,
      registrationNumber: json['registrationNumber'] as String,
      model: json['model'] as String?,
      engineCount: json['engineCount'] as int?,
      engineLabels:
          (json['engineLabels'] as List<dynamic>? ?? const <dynamic>[])
              .map((item) => item as String)
              .toList(),
      engineSerialNumbers:
          (json['engineSerialNumbers'] as List<dynamic>? ?? const <dynamic>[])
              .map((item) => '$item'.trim())
              .toList(),
      lengthMeters: (json['lengthMeters'] as num?)?.toDouble(),
      ownerId: json['ownerId'] as int,
      ownerName: json['ownerName'] as String,
    );
  }
}
