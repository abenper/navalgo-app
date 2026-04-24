class TimeAdjustmentRequest {
  const TimeAdjustmentRequest({
    required this.id,
    required this.workerId,
    required this.workerName,
    this.timeEntryId,
    required this.workDate,
    this.requestedClockIn,
    this.requestedClockOut,
    required this.workSite,
    required this.reason,
    required this.status,
    this.adminComment,
    this.createdAt,
    this.reviewedAt,
    this.reviewedByWorkerId,
    this.reviewedByWorkerName,
  });

  final int id;
  final int workerId;
  final String workerName;
  final int? timeEntryId;
  final DateTime workDate;
  final DateTime? requestedClockIn;
  final DateTime? requestedClockOut;
  final String workSite;
  final String reason;
  final String status;
  final String? adminComment;
  final DateTime? createdAt;
  final DateTime? reviewedAt;
  final int? reviewedByWorkerId;
  final String? reviewedByWorkerName;

  bool get isPending => status == 'PENDING';
  bool get isApproved => status == 'APPROVED';
  bool get isRejected => status == 'REJECTED';

  factory TimeAdjustmentRequest.fromJson(Map<String, dynamic> json) {
    DateTime? parseDateTime(dynamic value) {
      if (value is String) {
        return DateTime.tryParse(value);
      }
      if (value is num) {
        return DateTime.fromMillisecondsSinceEpoch(value.toInt(), isUtc: true);
      }
      return null;
    }

    final rawWorkDate = json['workDate'];
    final DateTime workDate = rawWorkDate is String
        ? DateTime.tryParse(rawWorkDate) ?? DateTime.now()
        : rawWorkDate is num
        ? DateTime.fromMillisecondsSinceEpoch(rawWorkDate.toInt(), isUtc: true)
        : DateTime.now();

    return TimeAdjustmentRequest(
      id: (json['id'] as num?)?.toInt() ?? 0,
      workerId: (json['workerId'] as num?)?.toInt() ?? 0,
      workerName: (json['workerName']?.toString() ?? '').trim(),
      timeEntryId: (json['timeEntryId'] as num?)?.toInt(),
      workDate: workDate,
      requestedClockIn: parseDateTime(json['requestedClockIn']),
      requestedClockOut: parseDateTime(json['requestedClockOut']),
      workSite: (json['workSite']?.toString() ?? 'WORKSHOP').trim(),
      reason: (json['reason']?.toString() ?? '').trim(),
      status: (json['status']?.toString() ?? 'PENDING').trim(),
      adminComment: json['adminComment']?.toString(),
      createdAt: parseDateTime(json['createdAt']),
      reviewedAt: parseDateTime(json['reviewedAt']),
      reviewedByWorkerId: (json['reviewedByWorkerId'] as num?)?.toInt(),
      reviewedByWorkerName: json['reviewedByWorkerName']?.toString(),
    );
  }
}