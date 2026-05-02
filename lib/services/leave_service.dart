import '../config/api_config.dart';
import '../models/leave_request.dart';
import 'network/api_client.dart';

class LeaveService {
  LeaveService({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient(baseUrl: ApiConfig.baseUrl);

  final ApiClient _apiClient;

  Future<List<LeaveRequestModel>> getLeaveRequests(
    String token, {
    int? workerId,
  }) async {
    final data = await _apiClient.get(
      '/leave-requests',
      headers: {'Authorization': 'Bearer $token'},
      queryParameters: workerId != null ? {'workerId': workerId} : null,
    );

    if (data is! List) {
      return <LeaveRequestModel>[];
    }

    return data
        .map((e) => LeaveRequestModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<LeaveRequestModel> createLeaveRequest(
    String token, {
    required int workerId,
    required String reason,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final data = await _apiClient.post(
      '/leave-requests',
      headers: {'Authorization': 'Bearer $token'},
      body: {
        'workerId': workerId,
        'reason': reason,
        'startDate': _asDate(startDate),
        'endDate': _asDate(endDate),
      },
    );

    return LeaveRequestModel.fromJson(data as Map<String, dynamic>);
  }

  Future<LeaveRequestModel> updateStatus(
    String token, {
    required int leaveRequestId,
    required String status,
  }) async {
    final data = await _apiClient.patch(
      '/leave-requests/$leaveRequestId/status',
      headers: {'Authorization': 'Bearer $token'},
      body: {'status': status},
    );

    return LeaveRequestModel.fromJson(data as Map<String, dynamic>);
  }

  Future<LeaveRequestModel> updateLeaveRequest(
    String token, {
    required int leaveRequestId,
    required String reason,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final data = await _apiClient.patch(
      '/leave-requests/$leaveRequestId',
      headers: {'Authorization': 'Bearer $token'},
      body: {
        'reason': reason,
        'startDate': _asDate(startDate),
        'endDate': _asDate(endDate),
      },
    );

    return LeaveRequestModel.fromJson(data as Map<String, dynamic>);
  }

  Future<void> cancelLeaveRequest(
    String token, {
    required int leaveRequestId,
  }) async {
    await _apiClient.delete(
      '/leave-requests/$leaveRequestId',
      headers: {'Authorization': 'Bearer $token'},
    );
  }

  Future<LeaveBalance> getLeaveBalance(
    String token, {
    int? workerId,
  }) async {
    final data = await _apiClient.get(
      '/leave-requests/balance',
      headers: {'Authorization': 'Bearer $token'},
      queryParameters: workerId != null ? {'workerId': workerId} : null,
    );

    return LeaveBalance.fromJson(data as Map<String, dynamic>);
  }

  Future<LeaveRequestModel> adminAssignLeave(
    String token, {
    required int workerId,
    required String reason,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final data = await _apiClient.post(
      '/leave-requests/admin-assign',
      headers: {'Authorization': 'Bearer $token'},
      body: {
        'workerId': workerId,
        'reason': reason,
        'startDate': _asDate(startDate),
        'endDate': _asDate(endDate),
      },
    );

    return LeaveRequestModel.fromJson(data as Map<String, dynamic>);
  }

  String _asDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}
