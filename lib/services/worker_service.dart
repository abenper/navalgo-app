import '../config/api_config.dart';
import '../models/worker_profile.dart';
import 'network/api_client.dart';

class CreateWorkerResult {
  const CreateWorkerResult({required this.worker, this.temporaryPassword});

  final WorkerProfile worker;
  final String? temporaryPassword;
}

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

  Future<CreateWorkerResult> createWorker(
    String token, {
    required String fullName,
    required String email,
    String? password,
    String? speciality,
    required String role,
    bool canEditWorkOrders = false,
  }) async {
    final data = await _apiClient.post(
      '/workers',
      headers: {'Authorization': 'Bearer $token'},
      body: {
        'fullName': fullName,
        'email': email,
        'password': password,
        'speciality': speciality,
        'role': role,
        'canEditWorkOrders': canEditWorkOrders,
      },
    );

    final map = data as Map<String, dynamic>;
    return CreateWorkerResult(
      worker: WorkerProfile.fromJson(map['worker'] as Map<String, dynamic>),
      temporaryPassword: map['temporaryPassword'] as String?,
    );
  }

  Future<WorkerProfile> updateActive(
    String token, {
    required int workerId,
    required bool active,
  }) async {
    final data = await _apiClient.patch(
      '/workers/$workerId/active',
      headers: {'Authorization': 'Bearer $token'},
      body: {'active': active},
    );
    return WorkerProfile.fromJson(data as Map<String, dynamic>);
  }

  Future<WorkerProfile> updateWorkOrderPermission(
    String token, {
    required int workerId,
    required bool canEditWorkOrders,
  }) async {
    final data = await _apiClient.patch(
      '/workers/$workerId/permissions/work-orders',
      headers: {'Authorization': 'Bearer $token'},
      body: {'canEditWorkOrders': canEditWorkOrders},
    );
    return WorkerProfile.fromJson(data as Map<String, dynamic>);
  }

  Future<String> resetPassword(String token, {required int workerId}) async {
    final data = await _apiClient.patch(
      '/workers/$workerId/reset-password',
      headers: {'Authorization': 'Bearer $token'},
    );
    final map = data as Map<String, dynamic>;
    return (map['temporaryPassword'] as String?) ?? '';
  }
}
