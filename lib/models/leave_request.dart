class LeaveRequestModel {
  const LeaveRequestModel({
    required this.id,
    required this.workerId,
    required this.workerName,
    required this.reason,
    required this.startDate,
    required this.endDate,
    required this.status,
  });

  final int id;
  final int workerId;
  final String workerName;
  final String reason;
  final DateTime startDate;
  final DateTime endDate;
  final String status;

  factory LeaveRequestModel.fromJson(Map<String, dynamic> json) {
    return LeaveRequestModel(
      id: json['id'] as int,
      workerId: json['workerId'] as int,
      workerName: json['workerName'] as String,
      reason: json['reason'] as String,
      startDate: DateTime.parse(json['startDate'] as String),
      endDate: DateTime.parse(json['endDate'] as String),
      status: json['status'] as String,
    );
  }
}
