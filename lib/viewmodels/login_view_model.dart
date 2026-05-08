import 'package:flutter/material.dart';

import '../models/user.dart';
import '../services/auth_service.dart';
import 'session_view_model.dart';

class LoginViewModel extends ChangeNotifier {
  LoginViewModel({AuthService? authService, required SessionViewModel session})
    : _authService = authService ?? AuthService(),
      _session = session;

  final AuthService _authService;
  final SessionViewModel _session;
  bool _isLoading = false;
  String? _errorMessage;
  User? _currentUser;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  User? get currentUser => _currentUser;

  Future<bool> login(
    String email,
    String password, {
    required bool rememberMe,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _currentUser = await _authService.login(email, password);
      await _session.setSession(_currentUser!, rememberMe: rememberMe);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
