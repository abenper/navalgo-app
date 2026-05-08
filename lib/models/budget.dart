class Budget {
  const Budget({
    required this.id,
    required this.ownerId,
    required this.ownerName,
    required this.ownerEmail,
    required this.clientHasAccount,
    required this.vesselId,
    required this.vesselName,
    required this.createdByWorkerId,
    required this.createdByWorkerName,
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
  });

  final int id;
  final int ownerId;
  final String ownerName;
  final String? ownerEmail;
  final bool clientHasAccount;
  final int vesselId;
  final String vesselName;
  final int createdByWorkerId;
  final String createdByWorkerName;
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

  factory Budget.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic value) {
      if (value is String && value.isNotEmpty) {
        return DateTime.tryParse(value);
      }
      return null;
    }

    return Budget(
      id: (json['id'] as num).toInt(),
      ownerId: (json['ownerId'] as num).toInt(),
      ownerName: json['ownerName'] as String,
      ownerEmail: json['ownerEmail'] as String?,
      clientHasAccount: json['clientHasAccount'] as bool? ?? false,
      vesselId: (json['vesselId'] as num).toInt(),
      vesselName: json['vesselName'] as String,
      createdByWorkerId: (json['createdByWorkerId'] as num).toInt(),
      createdByWorkerName: json['createdByWorkerName'] as String,
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
    );
  }
}

class UploadedBudgetDocument {
  const UploadedBudgetDocument({
    required this.fileUrl,
    this.originalFileName,
  });

  final String fileUrl;
  final String? originalFileName;

  factory UploadedBudgetDocument.fromJson(Map<String, dynamic> json) {
    return UploadedBudgetDocument(
      fileUrl: json['fileUrl'] as String,
      originalFileName: json['originalFileName'] as String?,
    );
  }
}
