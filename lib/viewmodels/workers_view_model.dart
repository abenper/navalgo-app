import 'package:flutter/material.dart';

import '../models/worker_profile.dart';
import '../services/worker_service.dart';
import 'session_view_model.dart';

class WorkersViewModel extends ChangeNotifier {
  WorkersViewModel({
    required WorkerService workerService,
    required SessionViewModel session,
  }) : _workerService = workerService,
       _session = session;

  final WorkerService _workerService;
  final SessionViewModel _session;

  bool _isLoading = false;
  String? _error;
  List<WorkerProfile> _workers = <WorkerProfile>[];

  bool get isLoading => _isLoading;
  String? get error => _error;
  List<WorkerProfile> get workers => _workers;

  Future<void> loadWorkers() async {
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
      _workers = await _workerService.getWorkers(token);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
