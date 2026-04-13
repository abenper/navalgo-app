class TimeEntry {
  const TimeEntry({
    required this.id,
    required this.workerId,
    required this.workerName,
    required this.clockIn,
    this.clockOut,
  });

  final int id;
  final int workerId;
  final String workerName;
  final DateTime clockIn;
  final DateTime? clockOut;

  factory TimeEntry.fromJson(Map<String, dynamic> json) {
    return TimeEntry(
      id: json['id'] as int,
      workerId: json['workerId'] as int,
      workerName: json['workerName'] as String,
      clockIn: DateTime.parse(json['clockIn'] as String),
      clockOut: json['clockOut'] == null
          ? null
          : DateTime.parse(json['clockOut'] as String),
    );
  }
}
