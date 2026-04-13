import 'package:flutter/material.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import 'session_view_model.dart';
// import 'package:shared_preferences/shared_preferences.dart'; // Para guardar la sesión en el futuro

class LoginViewModel extends ChangeNotifier {
  LoginViewModel({AuthService? authService, SessionViewModel? session})
    : _authService = authService ?? AuthService(),
      _session = session;

  final AuthService _authService;
  final SessionViewModel? _session;
  bool _isLoading = false;
  String? _errorMessage;
  User? _currentUser;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  User? get currentUser => _currentUser;

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners(); // Notifica a la UI que el estado de carga ha cambiado

    try {
      _currentUser = await _authService.login(email, password);
      _session?.setSession(_currentUser!);
      // Aquí podrías guardar el token y el rol en SharedPreferences
      // final prefs = await SharedPreferences.getInstance();
      // await prefs.setString('jwt_token', _currentUser!.token!);
      // await prefs.setString('user_role', _currentUser!.role);
      return true; // Login exitoso
    } catch (e) {
      _errorMessage = e.toString();
      return false; // Login fallido
    } finally {
      _isLoading = false;
      notifyListeners(); // Notifica a la UI que el estado final ha cambiado
    }
  }

  // Otros métodos como logout
}