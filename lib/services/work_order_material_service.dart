import '../config/api_config.dart';
import '../models/work_order.dart';
import 'network/api_client.dart';

class WorkOrderMaterialService {
  WorkOrderMaterialService({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient(baseUrl: ApiConfig.baseUrl);

  final ApiClient _apiClient;

  Future<WorkOrder> updateChecklist(
    String token, {
    required int workOrderId,
    required List<Map<String, dynamic>> items,
  }) async {
    final data = await _apiClient.patch(
      '/work-orders/$workOrderId/material-checklist',
      headers: {'Authorization': 'Bearer $token'},
      body: {'items': items},
    );
    return WorkOrder.fromJson(data as Map<String, dynamic>);
  }

  Future<WorkOrder> createRevisionRequest(
    String token, {
    required int workOrderId,
    required int checklistItemId,
    required String observations,
  }) async {
    final data = await _apiClient.post(
      '/work-orders/$workOrderId/material-revision-requests',
      headers: {'Authorization': 'Bearer $token'},
      body: {'checklistItemId': checklistItemId, 'observations': observations},
    );
    return WorkOrder.fromJson(data as Map<String, dynamic>);
  }

  Future<WorkOrder> updateRevisionRequestStatus(
    String token, {
    required int workOrderId,
    required int requestId,
    required String status,
    String? resolutionNote,
  }) async {
    final data = await _apiClient.patch(
      '/work-orders/$workOrderId/material-revision-requests/$requestId',
      headers: {'Authorization': 'Bearer $token'},
      body: {'status': status, 'resolutionNote': resolutionNote},
    );
    return WorkOrder.fromJson(data as Map<String, dynamic>);
  }
}
