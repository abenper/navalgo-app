class EngineHourLog {
  const EngineHourLog({required this.engineLabel, required this.hours});

  final String engineLabel;
  final int hours;

  factory EngineHourLog.fromJson(Map<String, dynamic> json) {
    final rawHours = json['hours'];
    final int parsedHours = rawHours is num
        ? rawHours.toInt()
        : int.tryParse(rawHours?.toString() ?? '') ?? 0;
    return EngineHourLog(
      engineLabel: (json['engineLabel'] as String?)?.trim().isNotEmpty == true
          ? (json['engineLabel'] as String).trim()
          : 'Motor',
      hours: parsedHours,
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
    double? parseDouble(dynamic value) {
      if (value is num) {
        return value.toDouble();
      }
      return double.tryParse(value?.toString() ?? '');
    }

    bool parseBool(dynamic value) {
      if (value is bool) {
        return value;
      }
      final raw = value?.toString().toLowerCase().trim();
      return raw == 'true' || raw == '1' || raw == 'yes';
    }

    final rawId = json['id'];
    final rawCapturedAt = json['capturedAt'];
    final DateTime? capturedAt = rawCapturedAt is String
        ? DateTime.tryParse(rawCapturedAt)
        : rawCapturedAt is num
            ? DateTime.fromMillisecondsSinceEpoch(rawCapturedAt.toInt(), isUtc: true)
            : null;

    final rawFileUrl = json['fileUrl']?.toString() ?? '';
    final rawFileType = json['fileType']?.toString().trim();
    final normalizedFileType = (rawFileType == null || rawFileType.isEmpty)
        ? (rawFileUrl.toLowerCase().endsWith('.mp4') ? 'VIDEO' : 'IMAGE')
        : rawFileType;

    return WorkOrderAttachmentItem(
      id: rawId is num ? rawId.toInt() : int.tryParse(rawId?.toString() ?? ''),
      fileUrl: rawFileUrl,
      fileType: normalizedFileType,
      originalFileName: json['originalFileName']?.toString(),
      capturedAt: capturedAt,
      latitude: parseDouble(json['latitude']),
      longitude: parseDouble(json['longitude']),
      watermarked: parseBool(json['watermarked']),
      audioRemoved: parseBool(json['audioRemoved']),
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
    String? asNullableString(dynamic value) {
      if (value == null) {
        return null;
      }
      final str = value.toString();
      return str.trim().isEmpty ? null : str;
    }

    final rawCreatedAt = json['createdAt'];
    final DateTime createdAt = rawCreatedAt is String
      ? DateTime.parse(rawCreatedAt)
      : rawCreatedAt is num
        ? DateTime.fromMillisecondsSinceEpoch(rawCreatedAt.toInt(), isUtc: true)
        : DateTime.now().toUtc();

    final rawSignedAt = json['signedAt'];
    final DateTime? signedAt = rawSignedAt is String
      ? DateTime.parse(rawSignedAt)
      : rawSignedAt is num
        ? DateTime.fromMillisecondsSinceEpoch(rawSignedAt.toInt(), isUtc: true)
        : null;

    final rawWorkerIds = json['workerIds'];
    final List<int> workerIds = rawWorkerIds is List
      ? rawWorkerIds
        .map((item) => item is num ? item.toInt() : int.tryParse(item.toString()))
        .whereType<int>()
        .toList()
      : <int>[];

    final rawWorkerNames = json['workerNames'];
    final List<String> workerNames = rawWorkerNames is List
      ? rawWorkerNames.map((item) => item.toString()).where((name) => name.trim().isNotEmpty).toList()
      : <String>[];

    final rawEngineHours = json['engineHours'];
    final List<EngineHourLog> engineHours = rawEngineHours is List
      ? rawEngineHours
        .whereType<Map<String, dynamic>>()
        .map(EngineHourLog.fromJson)
        .toList()
      : <EngineHourLog>[];

    final rawAttachmentUrls = json['attachmentUrls'];
    final List<String> attachmentUrls = rawAttachmentUrls is List
      ? rawAttachmentUrls
        .map((item) => item.toString())
        .where((url) => url.trim().isNotEmpty)
        .toList()
      : <String>[];

    final rawAttachments = json['attachments'];
    final List<WorkOrderAttachmentItem> attachments = rawAttachments is List
      ? rawAttachments
        .whereType<Map<String, dynamic>>()
        .map(WorkOrderAttachmentItem.fromJson)
        .toList()
      : <WorkOrderAttachmentItem>[];

    final rawOwnerId = json['ownerId'];
    final rawVesselId = json['vesselId'];
    final rawSignedByWorkerId = json['signedByWorkerId'];

    return WorkOrder(
      id: (json['id'] as num?)?.toInt() ?? 0,
      title: (json['title'] as String?)?.trim().isNotEmpty == true
        ? (json['title'] as String).trim()
        : 'Parte sin titulo',
      description: asNullableString(json['description']),
      status: asNullableString(json['status']) ?? 'OPEN',
      priority: asNullableString(json['priority']) ?? 'NORMAL',
      ownerId: rawOwnerId is num ? rawOwnerId.toInt() : 0,
      ownerName: (json['ownerName'] as String?)?.trim().isNotEmpty == true
        ? (json['ownerName'] as String).trim()
        : 'Propietario sin nombre',
      vesselId: rawVesselId is num ? rawVesselId.toInt() : null,
      vesselName: asNullableString(json['vesselName']),
      workerIds: workerIds,
      workerNames: workerNames,
      engineHours: engineHours,
      attachmentUrls: attachmentUrls,
      attachments: attachments,
      createdAt: createdAt,
      signatureUrl: asNullableString(json['signatureUrl']),
      signedAt: signedAt,
      signedByWorkerId: rawSignedByWorkerId is num ? rawSignedByWorkerId.toInt() : null,
      signedByWorkerName: asNullableString(json['signedByWorkerName']),
    );
  }
}
