class TimeEntry {
  const TimeEntry({
    required this.id,
    required this.workerId,
    required this.workerName,
    required this.clockIn,
    required this.workSite,
    this.clockOut,
    this.plannedClockOut,
    this.autoClosedAt,
    this.autoCloseReason,
  });

  final int id;
  final int workerId;
  final String workerName;
  final DateTime clockIn;
  final DateTime? clockOut;
  final String workSite;
  final DateTime? plannedClockOut;
  final DateTime? autoClosedAt;
  final String? autoCloseReason;

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
      plannedClockOut: json['plannedClockOut'] == null
          ? null
          : DateTime.parse(json['plannedClockOut'] as String),
      autoClosedAt: json['autoClosedAt'] == null
          ? null
          : DateTime.parse(json['autoClosedAt'] as String),
      autoCloseReason: json['autoCloseReason'] as String?,
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

class WorkerTimeTrackingStats {
  const WorkerTimeTrackingStats({
    required this.workerId,
    required this.workerName,
    required this.currentlyClockedIn,
    required this.workedMinutesToday,
    required this.workedMinutesThisMonth,
    required this.workedMinutesThisYear,
    required this.approvedNonVacationAbsenceDaysThisYear,
    required this.absenceVsAveragePercent,
  });

  final int workerId;
  final String workerName;
  final bool currentlyClockedIn;
  final int workedMinutesToday;
  final int workedMinutesThisMonth;
  final int workedMinutesThisYear;
  final int approvedNonVacationAbsenceDaysThisYear;
  final double absenceVsAveragePercent;

  factory WorkerTimeTrackingStats.fromJson(Map<String, dynamic> json) {
    return WorkerTimeTrackingStats(
      workerId: json['workerId'] as int,
      workerName: json['workerName'] as String? ?? 'Trabajador',
      currentlyClockedIn: json['currentlyClockedIn'] as bool? ?? false,
      workedMinutesToday: json['workedMinutesToday'] as int? ?? 0,
      workedMinutesThisMonth: json['workedMinutesThisMonth'] as int? ?? 0,
      workedMinutesThisYear: json['workedMinutesThisYear'] as int? ?? 0,
      approvedNonVacationAbsenceDaysThisYear:
          json['approvedNonVacationAbsenceDaysThisYear'] as int? ?? 0,
      absenceVsAveragePercent:
          (json['absenceVsAveragePercent'] as num?)?.toDouble() ?? 0,
    );
  }
}
