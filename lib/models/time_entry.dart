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
    this.clockInLatitude,
    this.clockInLongitude,
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
  final double? clockInLatitude;
  final double? clockInLongitude;

  factory TimeEntry.fromJson(Map<String, dynamic> json) {
    double? parseDouble(dynamic value) {
      if (value == null) {
        return null;
      }
      if (value is num) {
        return value.toDouble();
      }
      return double.tryParse('$value');
    }

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
      clockInLatitude: parseDouble(json['clockInLatitude']),
      clockInLongitude: parseDouble(json['clockInLongitude']),
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

class WorkerPerformanceFactor {
  const WorkerPerformanceFactor({
    required this.label,
    required this.score,
    required this.detail,
  });

  final String label;
  final double score;
  final String detail;

  factory WorkerPerformanceFactor.fromJson(Map<String, dynamic> json) {
    return WorkerPerformanceFactor(
      label: json['label'] as String? ?? '',
      score: (json['score'] as num?)?.toDouble() ?? 0,
      detail: json['detail'] as String? ?? '',
    );
  }
}

class WorkerResolvedWorkOrderStatsRow {
  const WorkerResolvedWorkOrderStatsRow({
    required this.label,
    required this.completedWorkOrders,
    required this.workedMinutes,
    required this.loggedLaborHours,
    required this.averageWorkedHoursPerOrder,
  });

  final String label;
  final int completedWorkOrders;
  final int workedMinutes;
  final double loggedLaborHours;
  final double averageWorkedHoursPerOrder;

  factory WorkerResolvedWorkOrderStatsRow.fromJson(
    Map<String, dynamic> json,
  ) {
    return WorkerResolvedWorkOrderStatsRow(
      label: json['label'] as String? ?? '',
      completedWorkOrders: json['completedWorkOrders'] as int? ?? 0,
      workedMinutes: json['workedMinutes'] as int? ?? 0,
      loggedLaborHours: (json['loggedLaborHours'] as num?)?.toDouble() ?? 0,
      averageWorkedHoursPerOrder:
          (json['averageWorkedHoursPerOrder'] as num?)?.toDouble() ?? 0,
    );
  }
}

class WorkerTimeTrackingInsight {
  const WorkerTimeTrackingInsight({
    required this.workerId,
    required this.workerName,
    required this.qualityScore,
    required this.currentlyClockedIn,
    required this.workedMinutesToday,
    required this.workedMinutesThisMonth,
    required this.workedMinutesThisYear,
    required this.approvedNonVacationAbsenceDaysThisYear,
    required this.absenceVsAveragePercent,
    required this.qualityFactors,
    required this.resolvedWorkOrderStats,
  });

  final int workerId;
  final String workerName;
  final double qualityScore;
  final bool currentlyClockedIn;
  final int workedMinutesToday;
  final int workedMinutesThisMonth;
  final int workedMinutesThisYear;
  final int approvedNonVacationAbsenceDaysThisYear;
  final double absenceVsAveragePercent;
  final List<WorkerPerformanceFactor> qualityFactors;
  final List<WorkerResolvedWorkOrderStatsRow> resolvedWorkOrderStats;

  factory WorkerTimeTrackingInsight.fromJson(Map<String, dynamic> json) {
    final rawFactors = json['qualityFactors'];
    final rawRows = json['resolvedWorkOrderStats'];
    return WorkerTimeTrackingInsight(
      workerId: json['workerId'] as int,
      workerName: json['workerName'] as String? ?? 'Trabajador',
      qualityScore: (json['qualityScore'] as num?)?.toDouble() ?? 0,
      currentlyClockedIn: json['currentlyClockedIn'] as bool? ?? false,
      workedMinutesToday: json['workedMinutesToday'] as int? ?? 0,
      workedMinutesThisMonth: json['workedMinutesThisMonth'] as int? ?? 0,
      workedMinutesThisYear: json['workedMinutesThisYear'] as int? ?? 0,
      approvedNonVacationAbsenceDaysThisYear:
          json['approvedNonVacationAbsenceDaysThisYear'] as int? ?? 0,
      absenceVsAveragePercent:
          (json['absenceVsAveragePercent'] as num?)?.toDouble() ?? 0,
      qualityFactors: rawFactors is List
          ? rawFactors
              .whereType<Map<String, dynamic>>()
              .map(WorkerPerformanceFactor.fromJson)
              .toList()
          : const <WorkerPerformanceFactor>[],
      resolvedWorkOrderStats: rawRows is List
          ? rawRows
              .whereType<Map<String, dynamic>>()
              .map(WorkerResolvedWorkOrderStatsRow.fromJson)
              .toList()
          : const <WorkerResolvedWorkOrderStatsRow>[],
    );
  }
}
