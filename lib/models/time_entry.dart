class TimeEntry {
  const TimeEntry({
    required this.id,
    required this.workerId,
    required this.workerName,
    required this.clockIn,
    required this.workSite,
    this.clockOut,
  });

  final int id;
  final int workerId;
  final String workerName;
  final DateTime clockIn;
  final DateTime? clockOut;
  final String workSite;

  factory TimeEntry.fromJson(Map<String, dynamic> json) {
    return TimeEntry(
      id: json['id'] as int,
      workerId: json['workerId'] as int,
      workerName: json['workerName'] as String,
      clockIn: DateTime.parse(json['clockIn'] as String),
      clockOut: json['clockOut'] == null
          ? null
          : DateTime.parse(json['clockOut'] as String),
      workSite: (json['workSite'] as String?) ?? 'WORKSHOP',
    );
  }
}

class TodayClockedWorkersSummary {
  const TodayClockedWorkersSummary({
    required this.clockedWorkersCount,
    required this.workerNames,
  });

  final int clockedWorkersCount;
  final List<String> workerNames;

  factory TodayClockedWorkersSummary.fromJson(Map<String, dynamic> json) {
    final rawNames = json['workerNames'];
    return TodayClockedWorkersSummary(
      clockedWorkersCount: json['clockedWorkersCount'] as int? ?? 0,
      workerNames: rawNames is List
          ? rawNames.map((item) => item.toString()).toList()
          : const <String>[],
    );
  }
}
