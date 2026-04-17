import '../config/api_config.dart';
import '../models/worker_profile.dart';
import 'network/api_client.dart';

class CreateWorkerResult {
  const CreateWorkerResult({required this.worker, this.temporaryPassword});

  final WorkerProfile worker;
  final String? temporaryPassword;
}

class UpdateOwnProfileResult {
  const UpdateOwnProfileResult({required this.worker, required this.token});

  final WorkerProfile worker;
  final String token;
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

  Future<WorkerProfile> getMyProfile(String token) async {
    final data = await _apiClient.get(
      '/workers/me',
      headers: {'Authorization': 'Bearer $token'},
    );
    return WorkerProfile.fromJson(data as Map<String, dynamic>);
  }

  Future<UpdateOwnProfileResult> updateMyProfile(
    String token, {
    required String fullName,
    required String email,
    String? speciality,
  }) async {
    final data = await _apiClient.put(
      '/workers/me',
      headers: {'Authorization': 'Bearer $token'},
      body: {
        'fullName': fullName,
        'email': email,
        'speciality': speciality,
      },
    );

    final map = data as Map<String, dynamic>;
    return UpdateOwnProfileResult(
      worker: WorkerProfile.fromJson(map['worker'] as Map<String, dynamic>),
      token: (map['token'] as String?) ?? token,
    );
  }

  Future<CreateWorkerResult> createWorker(
    String token, {
    required String fullName,
    required String email,
    String? password,
    String? speciality,
    required String role,
    bool canEditWorkOrders = false,
    DateTime? contractStartDate,
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
        'contractStartDate': _asDate(contractStartDate ?? DateTime.now()),
      },
    );

    final map = data as Map<String, dynamic>;
    return CreateWorkerResult(
      worker: WorkerProfile.fromJson(map['worker'] as Map<String, dynamic>),
      temporaryPassword: map['temporaryPassword'] as String?,
    );
  }

  Future<WorkerProfile> updateWorker(
    String token, {
    required int workerId,
    required String fullName,
    required String email,
    String? speciality,
    required String role,
    required bool canEditWorkOrders,
    required DateTime contractStartDate,
  }) async {
    final data = await _apiClient.put(
      '/workers/$workerId',
      headers: {'Authorization': 'Bearer $token'},
      body: {
        'fullName': fullName,
        'email': email,
        'speciality': speciality,
        'role': role,
        'canEditWorkOrders': canEditWorkOrders,
        'contractStartDate': _asDate(contractStartDate),
      },
    );

    return WorkerProfile.fromJson(data as Map<String, dynamic>);
  }

  Future<void> deleteWorker(String token, {required int workerId}) async {
    await _apiClient.delete(
      '/workers/$workerId',
      headers: {'Authorization': 'Bearer $token'},
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

  String _asDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}
