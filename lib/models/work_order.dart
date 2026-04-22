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
        ? DateTime.fromMillisecondsSinceEpoch(
            rawCapturedAt.toInt(),
            isUtc: true,
          )
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

class MaterialTemplateIncidentAlert {
  const MaterialTemplateIncidentAlert({
    required this.requestId,
    required this.articleName,
    required this.reference,
    required this.observations,
    required this.status,
    this.createdAt,
    this.requestedByWorkerName,
  });

  final int requestId;
  final String articleName;
  final String reference;
  final String observations;
  final String status;
  final DateTime? createdAt;
  final String? requestedByWorkerName;

  factory MaterialTemplateIncidentAlert.fromJson(Map<String, dynamic> json) {
    final rawCreatedAt = json['createdAt'];
    return MaterialTemplateIncidentAlert(
      requestId: (json['requestId'] as num?)?.toInt() ?? 0,
      articleName: (json['articleName']?.toString() ?? '').trim(),
      reference: (json['reference']?.toString() ?? '').trim(),
      observations: (json['observations']?.toString() ?? '').trim(),
      status: (json['status']?.toString() ?? 'PENDING').trim(),
      createdAt: rawCreatedAt is String
          ? DateTime.tryParse(rawCreatedAt)
          : rawCreatedAt is num
          ? DateTime.fromMillisecondsSinceEpoch(
              rawCreatedAt.toInt(),
              isUtc: true,
            )
          : null,
      requestedByWorkerName: json['requestedByWorkerName']?.toString(),
    );
  }
}

class MaterialChecklistTemplateItem {
  const MaterialChecklistTemplateItem({
    this.id,
    required this.articleName,
    required this.reference,
    required this.sortOrder,
  });

  final int? id;
  final String articleName;
  final String reference;
  final int sortOrder;

  factory MaterialChecklistTemplateItem.fromJson(Map<String, dynamic> json) {
    return MaterialChecklistTemplateItem(
      id: (json['id'] as num?)?.toInt(),
      articleName: (json['articleName']?.toString() ?? '').trim(),
      reference: (json['reference']?.toString() ?? '').trim(),
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'articleName': articleName,
      'reference': reference,
      'sortOrder': sortOrder,
    };
  }
}

class MaterialChecklistTemplate {
  const MaterialChecklistTemplate({
    this.id,
    required this.name,
    this.description,
    required this.items,
    this.createdAt,
    this.updatedAt,
    this.latestIncident,
  });

  final int? id;
  final String name;
  final String? description;
  final List<MaterialChecklistTemplateItem> items;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final MaterialTemplateIncidentAlert? latestIncident;

  factory MaterialChecklistTemplate.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic value) {
      if (value is String) {
        return DateTime.tryParse(value);
      }
      if (value is num) {
        return DateTime.fromMillisecondsSinceEpoch(value.toInt(), isUtc: true);
      }
      return null;
    }

    final rawItems = json['items'];
    return MaterialChecklistTemplate(
      id: (json['id'] as num?)?.toInt(),
      name: (json['name']?.toString() ?? '').trim(),
      description: json['description']?.toString(),
      items: rawItems is List
          ? rawItems
                .whereType<Map<String, dynamic>>()
                .map(MaterialChecklistTemplateItem.fromJson)
                .toList()
          : const <MaterialChecklistTemplateItem>[],
      createdAt: parseDate(json['createdAt']),
      updatedAt: parseDate(json['updatedAt']),
      latestIncident: json['latestIncident'] is Map<String, dynamic>
          ? MaterialTemplateIncidentAlert.fromJson(
              json['latestIncident'] as Map<String, dynamic>,
            )
          : null,
    );
  }
}

class WorkOrderMaterialChecklistItem {
  const WorkOrderMaterialChecklistItem({
    required this.id,
    this.sourceTemplateItemId,
    required this.articleName,
    required this.reference,
    required this.checked,
    this.checkedAt,
    this.checkedByWorkerId,
    this.checkedByWorkerName,
    required this.sortOrder,
  });

  final int id;
  final int? sourceTemplateItemId;
  final String articleName;
  final String reference;
  final bool checked;
  final DateTime? checkedAt;
  final int? checkedByWorkerId;
  final String? checkedByWorkerName;
  final int sortOrder;

  factory WorkOrderMaterialChecklistItem.fromJson(Map<String, dynamic> json) {
    final rawCheckedAt = json['checkedAt'];
    return WorkOrderMaterialChecklistItem(
      id: (json['id'] as num?)?.toInt() ?? 0,
      sourceTemplateItemId: (json['sourceTemplateItemId'] as num?)?.toInt(),
      articleName: (json['articleName']?.toString() ?? '').trim(),
      reference: (json['reference']?.toString() ?? '').trim(),
      checked: json['checked'] == true,
      checkedAt: rawCheckedAt is String
          ? DateTime.tryParse(rawCheckedAt)
          : rawCheckedAt is num
          ? DateTime.fromMillisecondsSinceEpoch(
              rawCheckedAt.toInt(),
              isUtc: true,
            )
          : null,
      checkedByWorkerId: (json['checkedByWorkerId'] as num?)?.toInt(),
      checkedByWorkerName: json['checkedByWorkerName']?.toString(),
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
    );
  }
}

class WorkOrderMaterialChecklist {
  const WorkOrderMaterialChecklist({
    required this.id,
    this.sourceTemplateId,
    required this.sourceTemplateName,
    this.assignedAt,
    required this.items,
  });

  final int id;
  final int? sourceTemplateId;
  final String sourceTemplateName;
  final DateTime? assignedAt;
  final List<WorkOrderMaterialChecklistItem> items;

  factory WorkOrderMaterialChecklist.fromJson(Map<String, dynamic> json) {
    final rawAssignedAt = json['assignedAt'];
    final rawItems = json['items'];
    return WorkOrderMaterialChecklist(
      id: (json['id'] as num?)?.toInt() ?? 0,
      sourceTemplateId: (json['sourceTemplateId'] as num?)?.toInt(),
      sourceTemplateName: (json['sourceTemplateName']?.toString() ?? '').trim(),
      assignedAt: rawAssignedAt is String
          ? DateTime.tryParse(rawAssignedAt)
          : rawAssignedAt is num
          ? DateTime.fromMillisecondsSinceEpoch(
              rawAssignedAt.toInt(),
              isUtc: true,
            )
          : null,
      items: rawItems is List
          ? rawItems
                .whereType<Map<String, dynamic>>()
                .map(WorkOrderMaterialChecklistItem.fromJson)
                .toList()
          : const <WorkOrderMaterialChecklistItem>[],
    );
  }
}

class MaterialRevisionRequest {
  const MaterialRevisionRequest({
    required this.id,
    this.checklistItemSnapshotId,
    this.sourceTemplateId,
    this.sourceTemplateItemId,
    required this.articleName,
    required this.reference,
    required this.observations,
    required this.status,
    this.requestedByWorkerId,
    this.requestedByWorkerName,
    this.createdAt,
    this.reviewedByWorkerId,
    this.reviewedByWorkerName,
    this.reviewedAt,
    this.resolutionNote,
  });

  final int id;
  final int? checklistItemSnapshotId;
  final int? sourceTemplateId;
  final int? sourceTemplateItemId;
  final String articleName;
  final String reference;
  final String observations;
  final String status;
  final int? requestedByWorkerId;
  final String? requestedByWorkerName;
  final DateTime? createdAt;
  final int? reviewedByWorkerId;
  final String? reviewedByWorkerName;
  final DateTime? reviewedAt;
  final String? resolutionNote;

  bool get isPending => status == 'PENDING';

  factory MaterialRevisionRequest.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic value) {
      if (value is String) {
        return DateTime.tryParse(value);
      }
      if (value is num) {
        return DateTime.fromMillisecondsSinceEpoch(value.toInt(), isUtc: true);
      }
      return null;
    }

    return MaterialRevisionRequest(
      id: (json['id'] as num?)?.toInt() ?? 0,
      checklistItemSnapshotId: (json['checklistItemSnapshotId'] as num?)
          ?.toInt(),
      sourceTemplateId: (json['sourceTemplateId'] as num?)?.toInt(),
      sourceTemplateItemId: (json['sourceTemplateItemId'] as num?)?.toInt(),
      articleName: (json['articleName']?.toString() ?? '').trim(),
      reference: (json['reference']?.toString() ?? '').trim(),
      observations: (json['observations']?.toString() ?? '').trim(),
      status: (json['status']?.toString() ?? 'PENDING').trim(),
      requestedByWorkerId: (json['requestedByWorkerId'] as num?)?.toInt(),
      requestedByWorkerName: json['requestedByWorkerName']?.toString(),
      createdAt: parseDate(json['createdAt']),
      reviewedByWorkerId: (json['reviewedByWorkerId'] as num?)?.toInt(),
      reviewedByWorkerName: json['reviewedByWorkerName']?.toString(),
      reviewedAt: parseDate(json['reviewedAt']),
      resolutionNote: json['resolutionNote']?.toString(),
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
    this.laborHours,
    this.materialChecklist,
    required this.materialRevisionRequests,
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
  final double? laborHours;
  final WorkOrderMaterialChecklist? materialChecklist;
  final List<MaterialRevisionRequest> materialRevisionRequests;
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
              .map(
                (item) =>
                    item is num ? item.toInt() : int.tryParse(item.toString()),
              )
              .whereType<int>()
              .toList()
        : <int>[];

    final rawWorkerNames = json['workerNames'];
    final List<String> workerNames = rawWorkerNames is List
        ? rawWorkerNames
              .map((item) => item.toString())
              .where((name) => name.trim().isNotEmpty)
              .toList()
        : <String>[];

    final rawEngineHours = json['engineHours'];
    final List<EngineHourLog> engineHours = rawEngineHours is List
        ? rawEngineHours
              .whereType<Map<String, dynamic>>()
              .map(EngineHourLog.fromJson)
              .toList()
        : <EngineHourLog>[];

    final rawMaterialRevisionRequests = json['materialRevisionRequests'];
    final List<MaterialRevisionRequest> materialRevisionRequests =
        rawMaterialRevisionRequests is List
        ? rawMaterialRevisionRequests
              .whereType<Map<String, dynamic>>()
              .map(MaterialRevisionRequest.fromJson)
              .toList()
        : <MaterialRevisionRequest>[];

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
      laborHours: (json['laborHours'] as num?)?.toDouble(),
      materialChecklist: json['materialChecklist'] is Map<String, dynamic>
          ? WorkOrderMaterialChecklist.fromJson(
              json['materialChecklist'] as Map<String, dynamic>,
            )
          : null,
      materialRevisionRequests: materialRevisionRequests,
      engineHours: engineHours,
      attachmentUrls: attachmentUrls,
      attachments: attachments,
      createdAt: createdAt,
      signatureUrl: asNullableString(json['signatureUrl']),
      signedAt: signedAt,
      signedByWorkerId: rawSignedByWorkerId is num
          ? rawSignedByWorkerId.toInt()
          : null,
      signedByWorkerName: asNullableString(json['signedByWorkerName']),
    );
  }
}
