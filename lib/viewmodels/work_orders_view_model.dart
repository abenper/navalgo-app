import 'package:flutter/material.dart';

import '../models/work_order.dart';
import '../services/work_order_service.dart';
import 'session_view_model.dart';

class WorkOrdersViewModel extends ChangeNotifier {
  WorkOrdersViewModel({
    required WorkOrderService workOrderService,
    required SessionViewModel session,
  }) : _workOrderService = workOrderService,
       _session = session;

  final WorkOrderService _workOrderService;
  final SessionViewModel _session;

  bool _isLoading = false;
  String? _error;
  List<WorkOrder> _workOrders = <WorkOrder>[];

  bool get isLoading => _isLoading;
  String? get error => _error;
  List<WorkOrder> get workOrders => _workOrders;

  Future<void> loadWorkOrders({int? workerId}) async {
    final token = _session.token;
    if (token == null || token.isEmpty) {
      _error = 'No hay sesion activa.';
      notifyListeners();
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _workOrders = await _workOrderService.getWorkOrders(
        token,
        workerId: workerId,
      );
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateWorkOrderStatus({
    required int workOrderId,
    required String status,
  }) async {
    final token = _session.token;
    if (token == null || token.isEmpty) {
      _error = 'No hay sesion activa.';
      notifyListeners();
      return;
    }

    try {
      final updated = await _workOrderService.updateStatus(
        token,
        workOrderId: workOrderId,
        status: status,
      );
      _workOrders = _workOrders
          .map((item) => item.id == workOrderId ? updated : item)
          .toList();
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }
}
