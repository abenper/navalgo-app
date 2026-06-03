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

class VesselEngineHourPoint {
  const VesselEngineHourPoint({
    required this.workOrderId,
    required this.workOrderTitle,
    required this.workOrderStatus,
    required this.hours,
    required this.recordedAt,
  });

  final int workOrderId;
  final String workOrderTitle;
  final String workOrderStatus;
  final int hours;
  final DateTime recordedAt;

  factory VesselEngineHourPoint.fromJson(Map<String, dynamic> json) {
    final rawId = json['workOrderId'];
    return VesselEngineHourPoint(
      workOrderId: rawId is num ? rawId.toInt() : 0,
      workOrderTitle: json['workOrderTitle']?.toString() ?? 'Parte',
      workOrderStatus: json['workOrderStatus']?.toString() ?? 'NEW',
      hours: (json['hours'] as num?)?.toInt() ?? 0,
      recordedAt: DateTime.parse(json['recordedAt'] as String),
    );
  }
}

class VesselEngineHourSeries {
  const VesselEngineHourSeries({
    required this.engineLabel,
    required this.points,
  });

  final String engineLabel;
  final List<VesselEngineHourPoint> points;

  int? get latestHours => points.isEmpty ? null : points.last.hours;

  factory VesselEngineHourSeries.fromJson(Map<String, dynamic> json) {
    final rawPoints = json['points'];
    return VesselEngineHourSeries(
      engineLabel: json['engineLabel']?.toString() ?? 'Motor',
      points: rawPoints is List
          ? rawPoints
                .whereType<Map<String, dynamic>>()
                .map(VesselEngineHourPoint.fromJson)
                .toList()
          : const <VesselEngineHourPoint>[],
    );
  }
}

class VesselWorkOrderMilestone {
  const VesselWorkOrderMilestone({
    required this.workOrderId,
    required this.workOrderTitle,
    required this.workOrderStatus,
    required this.recordedAt,
    this.maxHours,
    required this.engineHours,
  });

  final int workOrderId;
  final String workOrderTitle;
  final String workOrderStatus;
  final DateTime recordedAt;
  final int? maxHours;
  final List<EngineHourSummary> engineHours;

  factory VesselWorkOrderMilestone.fromJson(Map<String, dynamic> json) {
    final rawId = json['workOrderId'];
    final rawEngineHours = json['engineHours'];
    return VesselWorkOrderMilestone(
      workOrderId: rawId is num ? rawId.toInt() : 0,
      workOrderTitle: json['workOrderTitle']?.toString() ?? 'Parte',
      workOrderStatus: json['workOrderStatus']?.toString() ?? 'NEW',
      recordedAt: DateTime.parse(json['recordedAt'] as String),
      maxHours: (json['maxHours'] as num?)?.toInt(),
      engineHours: rawEngineHours is List
          ? rawEngineHours
                .whereType<Map<String, dynamic>>()
                .map(EngineHourSummary.fromJson)
                .toList()
          : const <EngineHourSummary>[],
    );
  }
}

class VesselStats {
  const VesselStats({
    required this.vesselId,
    required this.totalWorkOrders,
    required this.workOrdersWithEngineHours,
    this.firstRecordedAt,
    this.lastRecordedAt,
    this.highestRecordedHour,
    required this.latestEngineHours,
    required this.engineSeries,
    required this.workOrderMilestones,
  });

  final int vesselId;
  final int totalWorkOrders;
  final int workOrdersWithEngineHours;
  final DateTime? firstRecordedAt;
  final DateTime? lastRecordedAt;
  final int? highestRecordedHour;
  final List<EngineHourSummary> latestEngineHours;
  final List<VesselEngineHourSeries> engineSeries;
  final List<VesselWorkOrderMilestone> workOrderMilestones;

  bool get hasEngineData =>
      engineSeries.any((series) => series.points.isNotEmpty);

  factory VesselStats.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic value) {
      if (value is String && value.isNotEmpty) {
        return DateTime.tryParse(value);
      }
      return null;
    }

    final rawLatest = json['latestEngineHours'];
    final rawSeries = json['engineSeries'];
    final rawMilestones = json['workOrderMilestones'];

    return VesselStats(
      vesselId: (json['vesselId'] as num?)?.toInt() ?? 0,
      totalWorkOrders: (json['totalWorkOrders'] as num?)?.toInt() ?? 0,
      workOrdersWithEngineHours:
          (json['workOrdersWithEngineHours'] as num?)?.toInt() ?? 0,
      firstRecordedAt: parseDate(json['firstRecordedAt']),
      lastRecordedAt: parseDate(json['lastRecordedAt']),
      highestRecordedHour: (json['highestRecordedHour'] as num?)?.toInt(),
      latestEngineHours: rawLatest is List
          ? rawLatest
                .whereType<Map<String, dynamic>>()
                .map(EngineHourSummary.fromJson)
                .toList()
          : const <EngineHourSummary>[],
      engineSeries: rawSeries is List
          ? rawSeries
                .whereType<Map<String, dynamic>>()
                .map(VesselEngineHourSeries.fromJson)
                .toList()
          : const <VesselEngineHourSeries>[],
      workOrderMilestones: rawMilestones is List
          ? rawMilestones
                .whereType<Map<String, dynamic>>()
                .map(VesselWorkOrderMilestone.fromJson)
                .toList()
          : const <VesselWorkOrderMilestone>[],
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
    required this.hasJets,
    required this.jetLabels,
    required this.jetSerialNumbers,
    required this.hasGearboxes,
    required this.gearboxLabels,
    required this.gearboxSerialNumbers,
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
  final bool hasJets;
  final List<String> jetLabels;
  final List<String> jetSerialNumbers;
  final bool hasGearboxes;
  final List<String> gearboxLabels;
  final List<String> gearboxSerialNumbers;
  final double? lengthMeters;
  final int ownerId;
  final String ownerName;

  factory Vessel.fromJson(Map<String, dynamic> json) {
    return Vessel(
      id: json['id'] as int,
      name: json['name'] as String,
      registrationNumber: json['registrationNumber']?.toString() ?? '',
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
      hasJets: json['hasJets'] == true,
      jetLabels: (json['jetLabels'] as List<dynamic>? ?? const <dynamic>[])
          .map((item) => item as String)
          .toList(),
      jetSerialNumbers:
          (json['jetSerialNumbers'] as List<dynamic>? ?? const <dynamic>[])
              .map((item) => '$item'.trim())
              .toList(),
      hasGearboxes: json['hasGearboxes'] == true,
      gearboxLabels:
          (json['gearboxLabels'] as List<dynamic>? ?? const <dynamic>[])
              .map((item) => item as String)
              .toList(),
      gearboxSerialNumbers:
          (json['gearboxSerialNumbers'] as List<dynamic>? ?? const <dynamic>[])
              .map((item) => '$item'.trim())
              .toList(),
      lengthMeters: (json['lengthMeters'] as num?)?.toDouble(),
      ownerId: json['ownerId'] as int,
      ownerName: json['ownerName'] as String,
    );
  }
}
