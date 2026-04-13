import '../config/api_config.dart';
import '../models/worker_profile.dart';
import 'network/api_client.dart';

class WorkerService {
  WorkerService({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient(baseUrl: ApiConfig.baseUrl);

  final ApiClient _apiClient;

  Future<List<WorkerProfile>> getWorkers(String token) async {
    final data = await _apiClient.get(
      '/workers',
      headers: {'Authorization': 'Bearer $token'},
    );

    if (data is! List) {
      return <WorkerProfile>[];
    }

    return data
        .map((item) => WorkerProfile.fromJson(item as Map<String, dynamic>))
        .toList();
  }
}
