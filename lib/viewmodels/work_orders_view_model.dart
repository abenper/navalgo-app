import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

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
  bool _isDisposed = false;
  bool _notificationScheduled = false;
  String? _error;
  List<WorkOrder> _workOrders = <WorkOrder>[];

  bool get isLoading => _isLoading;
  String? get error => _error;
  List<WorkOrder> get workOrders => _workOrders;

  void _notifyListenersSafely() {
    if (_isDisposed) {
      return;
    }

    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.idle ||
        phase == SchedulerPhase.postFrameCallbacks) {
      notifyListeners();
      return;
    }

    if (_notificationScheduled) {
      return;
    }

    _notificationScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _notificationScheduled = false;
      if (_isDisposed) {
        return;
      }
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  Future<void> loadWorkOrders({int? workerId}) async {
    final token = _session.token;
    if (token == null || token.isEmpty) {
      _error = 'No hay sesion activa.';
      _notifyListenersSafely();
      return;
    }

    _isLoading = true;
    _error = null;
    _notifyListenersSafely();

    try {
      _workOrders = await _workOrderService.getWorkOrders(
        token,
        workerId: workerId,
      );
      _workOrders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      _notifyListenersSafely();
    }
  }

  Future<void> updateWorkOrderStatus({
    required int workOrderId,
    required String status,
  }) async {
    final token = _session.token;
    if (token == null || token.isEmpty) {
      _error = 'No hay sesion activa.';
      _notifyListenersSafely();
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
      _notifyListenersSafely();
    } catch (e) {
      _error = e.toString();
      _notifyListenersSafely();
    }
  }
}
