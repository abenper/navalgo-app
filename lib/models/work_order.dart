class EngineHourLog {
  const EngineHourLog({required this.engineLabel, required this.hours});

  final String engineLabel;
  final int hours;

  factory EngineHourLog.fromJson(Map<String, dynamic> json) {
    return EngineHourLog(
      engineLabel: json['engineLabel'] as String,
      hours: json['hours'] as int,
    );
  }
}

class WorkOrder {
  const WorkOrder({
    required this.id,
    required this.title,
    this.description,
    required this.status,
    required this.priority,
    required this.ownerId,
    required this.ownerName,
    this.vesselId,
    this.vesselName,
    required this.workerIds,
    required this.workerNames,
    required this.engineHours,
    required this.attachmentUrls,
    required this.createdAt,
  });

  final int id;
  final String title;
  final String? description;
  final String status;
  final String priority;
  final int ownerId;
  final String ownerName;
  final int? vesselId;
  final String? vesselName;
  final List<int> workerIds;
  final List<String> workerNames;
  final List<EngineHourLog> engineHours;
  final List<String> attachmentUrls;
  final DateTime createdAt;

  factory WorkOrder.fromJson(Map<String, dynamic> json) {
    return WorkOrder(
      id: json['id'] as int,
      title: json['title'] as String,
      description: json['description'] as String?,
      status: json['status'] as String,
      priority: json['priority'] as String,
      ownerId: json['ownerId'] as int,
      ownerName: json['ownerName'] as String,
      vesselId: json['vesselId'] as int?,
      vesselName: json['vesselName'] as String?,
      workerIds: (json['workerIds'] as List<dynamic>).cast<int>(),
      workerNames: (json['workerNames'] as List<dynamic>).cast<String>(),
      engineHours: (json['engineHours'] as List<dynamic>)
          .map((e) => EngineHourLog.fromJson(e as Map<String, dynamic>))
          .toList(),
      attachmentUrls: (json['attachmentUrls'] as List<dynamic>).cast<String>(),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
