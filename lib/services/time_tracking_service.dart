import '../config/api_config.dart';
import '../models/time_adjustment_request.dart';
import '../models/time_entry.dart';
import 'network/api_client.dart';

class TimeTrackingService {
  TimeTrackingService({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient(baseUrl: ApiConfig.baseUrl);

  final ApiClient _apiClient;

  String _formatDate(DateTime value) {
    final normalized = DateTime(value.year, value.month, value.day);
    final month = normalized.month.toString().padLeft(2, '0');
    final day = normalized.day.toString().padLeft(2, '0');
    return '${normalized.year}-$month-$day';
  }

  Future<TimeEntry> clockIn(
    String token, {
    required int workerId,
    required String workSite,
  }) async {
    final data = await _apiClient.post(
      '/time-entries/clock-in',
      headers: {'Authorization': 'Bearer $token'},
      body: {'workerId': workerId, 'workSite': workSite},
    );
    return TimeEntry.fromJson(data as Map<String, dynamic>);
  }

  Future<TimeEntry> clockOut(String token, {required int workerId}) async {
    final data = await _apiClient.post(
      '/time-entries/clock-out',
      headers: {'Authorization': 'Bearer $token'},
      body: {'workerId': workerId},
    );
    return TimeEntry.fromJson(data as Map<String, dynamic>);
  }

  Future<List<TimeEntry>> getByWorker(
    String token, {
    required int workerId,
  }) async {
    final data = await _apiClient.get(
      '/time-entries/worker/$workerId',
      headers: {'Authorization': 'Bearer $token'},
    );
    if (data is! List) {
      return <TimeEntry>[];
    }
    return data
        .map((e) => TimeEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<TodayClockedWorkersSummary> getTodaySummary(String token) async {
    final data = await _apiClient.get(
      '/time-entries/today-summary',
      headers: {'Authorization': 'Bearer $token'},
    );
    return TodayClockedWorkersSummary.fromJson(data as Map<String, dynamic>);
  }

  Future<List<TimeAdjustmentRequest>> getAdjustmentRequests(
    String token, {
    String? status,
  }) async {
    final data = await _apiClient.get(
      '/time-adjustments',
      headers: {'Authorization': 'Bearer $token'},
      queryParameters: status == null ? null : {'status': status},
    );
    if (data is! List) {
      return <TimeAdjustmentRequest>[];
    }
    return data
        .whereType<Map<String, dynamic>>()
        .map(TimeAdjustmentRequest.fromJson)
        .toList();
  }

  Future<TimeAdjustmentRequest> createAdjustmentRequest(
    String token, {
    int? timeEntryId,
    required DateTime workDate,
    DateTime? requestedClockIn,
    DateTime? requestedClockOut,
    required String workSite,
    required String reason,
  }) async {
    final data = await _apiClient.post(
      '/time-adjustments',
      headers: {'Authorization': 'Bearer $token'},
      body: {
        'timeEntryId': timeEntryId,
        'workDate': _formatDate(workDate),
        'requestedClockIn': requestedClockIn?.toUtc().toIso8601String(),
        'requestedClockOut': requestedClockOut?.toUtc().toIso8601String(),
        'workSite': workSite,
        'reason': reason,
      },
    );
    return TimeAdjustmentRequest.fromJson(data as Map<String, dynamic>);
  }

  Future<TimeAdjustmentRequest> reviewAdjustmentRequest(
    String token, {
    required int requestId,
    required String status,
    String? adminComment,
  }) async {
    final data = await _apiClient.patch(
      '/time-adjustments/$requestId/status',
      headers: {'Authorization': 'Bearer $token'},
      body: {'status': status, 'adminComment': adminComment},
    );
    return TimeAdjustmentRequest.fromJson(data as Map<String, dynamic>);
  }

  Future<TimeAdjustmentRequest> updateAdjustmentRequest(
    String token, {
    required int requestId,
    int? timeEntryId,
    required DateTime workDate,
    DateTime? requestedClockIn,
    DateTime? requestedClockOut,
    required String workSite,
    required String reason,
  }) async {
    final data = await _apiClient.patch(
      '/time-adjustments/$requestId',
      headers: {'Authorization': 'Bearer $token'},
      body: {
        'timeEntryId': timeEntryId,
        'workDate': _formatDate(workDate),
        'requestedClockIn': requestedClockIn?.toUtc().toIso8601String(),
        'requestedClockOut': requestedClockOut?.toUtc().toIso8601String(),
        'workSite': workSite,
        'reason': reason,
      },
    );
    return TimeAdjustmentRequest.fromJson(data as Map<String, dynamic>);
  }

  Future<void> deleteAdjustmentRequest(
    String token, {
    required int requestId,
  }) async {
    await _apiClient.delete(
      '/time-adjustments/$requestId',
      headers: {'Authorization': 'Bearer $token'},
    );
  }
}
