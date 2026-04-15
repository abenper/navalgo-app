import '../config/api_config.dart';
import '../models/work_order.dart';
import 'network/api_client.dart';

class WorkOrderService {
  WorkOrderService({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient(baseUrl: ApiConfig.baseUrl);

  final ApiClient _apiClient;

  Future<List<WorkOrder>> getWorkOrders(String token, {int? workerId}) async {
    final data = await _apiClient.get(
      '/work-orders',
      headers: {'Authorization': 'Bearer $token'},
      queryParameters: workerId != null ? {'workerId': workerId} : null,
    );

    if (data is! List) {
      return <WorkOrder>[];
    }

    return data
        .map((item) => WorkOrder.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<WorkOrder> updateStatus(
    String token, {
    required int workOrderId,
    required String status,
  }) async {
    final data = await _apiClient.patch(
      '/work-orders/$workOrderId/status',
      headers: {'Authorization': 'Bearer $token'},
      body: {'status': status},
    );

    return WorkOrder.fromJson(data as Map<String, dynamic>);
  }

  Future<WorkOrder> createWorkOrder(
    String token, {
    required String title,
    String? description,
    required int ownerId,
    int? vesselId,
    List<int>? workerIds,
    List<Map<String, dynamic>>? engineHours,
    List<String>? attachmentUrls,
    List<WorkOrderAttachmentItem>? attachments,
    String priority = 'NORMAL',
  }) async {
    final data = await _apiClient.post(
      '/work-orders',
      headers: {'Authorization': 'Bearer $token'},
      body: {
        'title': title,
        'description': description,
        'ownerId': ownerId,
        'vesselId': vesselId,
        'workerIds': workerIds,
        'engineHours': engineHours,
        'attachmentUrls': attachmentUrls,
        'attachments': attachments?.map((item) => item.toJson()).toList(),
        'priority': priority,
      },
    );
    return WorkOrder.fromJson(data as Map<String, dynamic>);
  }

  Future<WorkOrder> updateWorkOrder(
    String token, {
    required int workOrderId,
    String? title,
    String? description,
    int? ownerId,
    int? vesselId,
    List<int>? workerIds,
    String? priority,
    String? status,
    bool? clearSignature,
    List<WorkOrderAttachmentItem>? attachments,
  }) async {
    final data = await _apiClient.patch(
      '/work-orders/$workOrderId',
      headers: {'Authorization': 'Bearer $token'},
      body: {
        'title': title,
        'description': description,
        'ownerId': ownerId,
        'vesselId': vesselId,
        'workerIds': workerIds,
        'priority': priority,
        'status': status,
        'clearSignature': clearSignature,
        'attachments': attachments?.map((item) => item.toJson()).toList(),
      },
    );
    return WorkOrder.fromJson(data as Map<String, dynamic>);
  }

  Future<WorkOrder> deleteAttachment(
    String token, {
    required int workOrderId,
    required int attachmentId,
  }) async {
    final data = await _apiClient.delete(
      '/work-orders/$workOrderId/attachments/$attachmentId',
      headers: {'Authorization': 'Bearer $token'},
    );
    return WorkOrder.fromJson(data as Map<String, dynamic>);
  }
}
