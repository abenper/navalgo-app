import '../config/api_config.dart';
import '../models/time_entry.dart';
import 'network/api_client.dart';

class TimeTrackingService {
  TimeTrackingService({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient(baseUrl: ApiConfig.baseUrl);

  final ApiClient _apiClient;

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
}
