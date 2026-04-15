class LeaveRequestModel {
  const LeaveRequestModel({
    required this.id,
    required this.workerId,
    required this.workerName,
    required this.reason,
    required this.startDate,
    required this.endDate,
    required this.requestedDays,
    required this.status,
  });

  final int id;
  final int workerId;
  final String workerName;
  final String reason;
  final DateTime startDate;
  final DateTime endDate;
  final int requestedDays;
  final String status;

  factory LeaveRequestModel.fromJson(Map<String, dynamic> json) {
    return LeaveRequestModel(
      id: json['id'] as int,
      workerId: json['workerId'] as int,
      workerName: json['workerName'] as String,
      reason: json['reason'] as String,
      startDate: DateTime.parse(json['startDate'] as String),
      endDate: DateTime.parse(json['endDate'] as String),
      requestedDays: json['requestedDays'] as int? ?? 0,
      status: json['status'] as String,
    );
  }
}

class LeaveBalance {
  const LeaveBalance({
    required this.workerId,
    required this.workerName,
    required this.accruedDays,
    required this.consumedDays,
    required this.availableDays,
  });

  final int workerId;
  final String workerName;
  final double accruedDays;
  final int consumedDays;
  final double availableDays;

  factory LeaveBalance.fromJson(Map<String, dynamic> json) {
    return LeaveBalance(
      workerId: json['workerId'] as int,
      workerName: json['workerName'] as String,
      accruedDays: (json['accruedDays'] as num?)?.toDouble() ?? 0,
      consumedDays: json['consumedDays'] as int? ?? 0,
      availableDays: (json['availableDays'] as num?)?.toDouble() ?? 0,
    );
  }
}
