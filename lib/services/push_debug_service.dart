import '../config/api_config.dart';
import '../models/push_debug.dart';
import 'network/api_client.dart';

class PushDebugService {
  PushDebugService({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient(baseUrl: ApiConfig.baseUrl);

  final ApiClient _apiClient;

  Future<PushDebugStatus> getStatus(String token) async {
    final data = await _apiClient.get(
      '/push-debug/status',
      headers: {'Authorization': 'Bearer $token'},
    );
    return PushDebugStatus.fromJson(data as Map<String, dynamic>);
  }

  Future<List<PushDebugToken>> getTokens(String token) async {
    final data = await _apiClient.get(
      '/push-debug/tokens',
      headers: {'Authorization': 'Bearer $token'},
    );
    if (data is! List) {
      return <PushDebugToken>[];
    }

    return data
        .whereType<Map<String, dynamic>>()
        .map(PushDebugToken.fromJson)
        .toList();
  }

  Future<void> sendSelfTest(String token) async {
    await _apiClient.post(
      '/push-debug/send-self-test',
      headers: {'Authorization': 'Bearer $token'},
    );
  }
}
