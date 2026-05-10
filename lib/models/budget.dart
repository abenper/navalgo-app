class Budget {
  const Budget({
    required this.id,
    required this.ownerId,
    required this.ownerName,
    required this.ownerEmail,
    required this.walkInClient,
    required this.clientHasAccount,
    required this.vesselId,
    required this.vesselName,
    required this.createdByWorkerId,
    required this.createdByWorkerName,
    this.originBudgetId,
    this.originBudgetTitle,
    required this.title,
    this.description,
    this.amount,
    required this.currency,
    required this.pdfUrl,
    required this.status,
    this.clientObservations,
    this.sentAt,
    this.clientDecidedAt,
    required this.createdAt,
    required this.updatedAt,
    required this.timeline,
  });

  final int id;
  final int? ownerId;
  final String ownerName;
  final String? ownerEmail;
  final bool walkInClient;
  final bool clientHasAccount;
  final int? vesselId;
  final String vesselName;
  final int createdByWorkerId;
  final String createdByWorkerName;
  final int? originBudgetId;
  final String? originBudgetTitle;
  final String title;
  final String? description;
  final double? amount;
  final String currency;
  final String pdfUrl;
  final String status;
  final String? clientObservations;
  final DateTime? sentAt;
  final DateTime? clientDecidedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<BudgetTimelineEntry> timeline;

  factory Budget.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic value) {
      if (value is String && value.isNotEmpty) {
        return DateTime.tryParse(value);
      }
      return null;
    }

    final rawTimeline = json['timeline'];
    return Budget(
      id: (json['id'] as num).toInt(),
      ownerId: (json['ownerId'] as num?)?.toInt(),
      ownerName: json['ownerName'] as String,
      ownerEmail: json['ownerEmail'] as String?,
      walkInClient: json['walkInClient'] as bool? ?? false,
      clientHasAccount: json['clientHasAccount'] as bool? ?? false,
      vesselId: (json['vesselId'] as num?)?.toInt(),
      vesselName: json['vesselName'] as String? ?? 'Sin embarcacion',
      createdByWorkerId: (json['createdByWorkerId'] as num).toInt(),
      createdByWorkerName: json['createdByWorkerName'] as String,
      originBudgetId: (json['originBudgetId'] as num?)?.toInt(),
      originBudgetTitle: json['originBudgetTitle'] as String?,
      title: json['title'] as String,
      description: json['description'] as String?,
      amount: (json['amount'] as num?)?.toDouble(),
      currency: json['currency'] as String? ?? 'EUR',
      pdfUrl: json['pdfUrl'] as String,
      status: json['status'] as String,
      clientObservations: json['clientObservations'] as String?,
      sentAt: parseDate(json['sentAt']),
      clientDecidedAt: parseDate(json['clientDecidedAt']),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      timeline: rawTimeline is List
          ? rawTimeline
                .whereType<Map<String, dynamic>>()
                .map(BudgetTimelineEntry.fromJson)
                .toList()
          : const <BudgetTimelineEntry>[],
    );
  }
}

class BudgetTimelineEntry {
  const BudgetTimelineEntry({
    required this.eventType,
    required this.actorName,
    required this.actorRole,
    this.note,
    required this.createdAt,
  });

  final String eventType;
  final String actorName;
  final String actorRole;
  final String? note;
  final DateTime createdAt;

  factory BudgetTimelineEntry.fromJson(Map<String, dynamic> json) {
    return BudgetTimelineEntry(
      eventType: json['eventType'] as String? ?? 'CREATED',
      actorName: json['actorName'] as String? ?? 'Sistema',
      actorRole: json['actorRole'] as String? ?? 'SYSTEM',
      note: json['note'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

class UploadedBudgetDocument {
  const UploadedBudgetDocument({required this.fileUrl, this.originalFileName});

  final String fileUrl;
  final String? originalFileName;

  factory UploadedBudgetDocument.fromJson(Map<String, dynamic> json) {
    return UploadedBudgetDocument(
      fileUrl: json['fileUrl'] as String,
      originalFileName: json['originalFileName'] as String?,
    );
  }
}
