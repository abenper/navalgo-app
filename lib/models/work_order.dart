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

class WorkOrderAttachmentItem {
  const WorkOrderAttachmentItem({
    this.id,
    required this.fileUrl,
    required this.fileType,
    this.originalFileName,
    this.capturedAt,
    this.latitude,
    this.longitude,
    required this.watermarked,
    required this.audioRemoved,
  });

  final int? id;
  final String fileUrl;
  final String fileType;
  final String? originalFileName;
  final DateTime? capturedAt;
  final double? latitude;
  final double? longitude;
  final bool watermarked;
  final bool audioRemoved;

  factory WorkOrderAttachmentItem.fromJson(Map<String, dynamic> json) {
    return WorkOrderAttachmentItem(
      id: json['id'] as int?,
      fileUrl: json['fileUrl'] as String,
      fileType: json['fileType'] as String,
      originalFileName: json['originalFileName'] as String?,
      capturedAt: json['capturedAt'] == null
          ? null
          : DateTime.parse(json['capturedAt'] as String),
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      watermarked: json['watermarked'] as bool? ?? false,
      audioRemoved: json['audioRemoved'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fileUrl': fileUrl,
      'fileType': fileType,
      'originalFileName': originalFileName,
      'capturedAt': capturedAt?.toIso8601String(),
      'latitude': latitude,
      'longitude': longitude,
      'watermarked': watermarked,
      'audioRemoved': audioRemoved,
    };
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
    required this.attachments,
    required this.createdAt,
    this.signatureUrl,
    this.signedAt,
    this.signedByWorkerId,
    this.signedByWorkerName,
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
  final List<WorkOrderAttachmentItem> attachments;
  final DateTime createdAt;
  final String? signatureUrl;
  final DateTime? signedAt;
  final int? signedByWorkerId;
  final String? signedByWorkerName;

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
      attachments: (json['attachments'] as List<dynamic>? ?? const <dynamic>[])
          .map((e) => WorkOrderAttachmentItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      signatureUrl: json['signatureUrl'] as String?,
      signedAt: json['signedAt'] == null ? null : DateTime.parse(json['signedAt'] as String),
      signedByWorkerId: json['signedByWorkerId'] as int?,
      signedByWorkerName: json['signedByWorkerName'] as String?,
    );
  }
}
