class Vessel {
  const Vessel({
    required this.id,
    required this.name,
    required this.registrationNumber,
    this.model,
    this.engineCount,
    required this.engineLabels,
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
      engineLabels: (json['engineLabels'] as List<dynamic>? ?? const <dynamic>[])
          .map((item) => item as String)
          .toList(),
      lengthMeters: (json['lengthMeters'] as num?)?.toDouble(),
      ownerId: json['ownerId'] as int,
      ownerName: json['ownerName'] as String,
    );
  }
}
