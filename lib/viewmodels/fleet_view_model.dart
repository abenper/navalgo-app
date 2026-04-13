import 'package:flutter/material.dart';

import '../models/owner.dart';
import '../models/vessel.dart';
import '../services/fleet_service.dart';
import 'session_view_model.dart';

class FleetViewModel extends ChangeNotifier {
  FleetViewModel({
    required FleetService fleetService,
    required SessionViewModel session,
  }) : _fleetService = fleetService,
       _session = session;

  final FleetService _fleetService;
  final SessionViewModel _session;

  bool _isLoading = false;
  String? _error;
  List<Owner> _owners = <Owner>[];
  List<Vessel> _vessels = <Vessel>[];

  bool get isLoading => _isLoading;
  String? get error => _error;
  List<Owner> get owners => _owners;
  List<Vessel> get vessels => _vessels;

  Future<void> loadFleet({int? ownerId}) async {
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
      _owners = await _fleetService.getOwners(token);
      _vessels = await _fleetService.getVessels(token, ownerId: ownerId);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
