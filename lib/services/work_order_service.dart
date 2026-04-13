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
}
