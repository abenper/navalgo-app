import '../config/api_config.dart';
import '../models/work_order.dart';
import 'network/api_client.dart';

class WorkOrderService {
  WorkOrderService({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient(baseUrl: ApiConfig.baseUrl);

  final ApiClient _apiClient;

  Future<WorkOrder> getWorkOrder(
    String token, {
    required int workOrderId,
  }) async {
    final data = await _apiClient.get(
      '/work-orders/$workOrderId',
      headers: {'Authorization': 'Bearer $token'},
    );

    return WorkOrder.fromJson(data as Map<String, dynamic>);
  }

  Future<List<WorkOrder>> getWorkOrders(String token, {int? workerId}) async {
    final data = await _apiClient.get(
      '/work-orders',
      headers: {'Authorization': 'Bearer $token'},
      queryParameters: workerId != null ? {'workerId': workerId} : null,
    );

    final List<dynamic> rawList;
    if (data is List) {
      rawList = data;
    } else if (data is Map<String, dynamic> && data['content'] is List) {
      rawList = data['content'] as List<dynamic>;
    } else {
      return <WorkOrder>[];
    }

    final workOrders = <WorkOrder>[];
    for (final item in rawList) {
      if (item is! Map<String, dynamic>) {
        continue;
      }
      try {
        workOrders.add(WorkOrder.fromJson(item));
      } catch (_) {
        // Skip malformed items so one broken record does not hide the full list.
      }
    }

    return workOrders;
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
    double? laborHours,
    int? materialTemplateId,
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
        'laborHours': laborHours,
        'materialTemplateId': materialTemplateId,
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
    double? laborHours,
    int? materialTemplateId,
    bool? clearMaterialChecklist,
    List<Map<String, dynamic>>? engineHours,
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
        'laborHours': laborHours,
        'materialTemplateId': materialTemplateId,
        'clearMaterialChecklist': clearMaterialChecklist,
        'engineHours': engineHours,
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

  Future<void> deleteWorkOrder(String token, {required int workOrderId}) async {
    await _apiClient.delete(
      '/work-orders/$workOrderId',
      headers: {'Authorization': 'Bearer $token'},
    );
  }
}
