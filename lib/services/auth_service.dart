import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/user.dart'; // Tu modelo de usuario
import '../config/api_config.dart';
import 'network/api_client.dart';
import 'network/api_exception.dart';

class AuthService {
  AuthService({ApiClient? apiClient, http.Client? httpClient})
    : _apiClient =
          apiClient ??
          ApiClient(baseUrl: ApiConfig.baseUrl, httpClient: httpClient);

  final ApiClient _apiClient;

  Future<RegistrationInvitationInfo> getRegistrationInvitationStatus(
    String token,
  ) async {
    final data = await _apiClient.get(
      '/auth/registration-invitations/status',
      queryParameters: {'token': token},
    );
    final map = data as Map<String, dynamic>;
    return RegistrationInvitationInfo(
      fullName: (map['fullName'] as String?) ?? '',
      email: (map['email'] as String?) ?? '',
      expiresAt: DateTime.parse(map['expiresAt'] as String),
    );
  }

  Future<void> completeRegistration({
    required String token,
    required String password,
  }) async {
    await _apiClient.post(
      '/auth/registration-invitations/complete',
      body: {'token': token, 'password': password},
    );
  }

  Future<void> signupClient({
    required String fullName,
    required String email,
    required String password,
    String? phone,
  }) async {
    await _apiClient.post(
      '/auth/clients/signup',
      body: {
        'fullName': fullName,
        'email': email,
        'password': password,
        'phone': phone,
      },
    );
  }

  Future<EmailVerificationInfo> getEmailVerificationStatus(String token) async {
    final data = await _apiClient.get(
      '/auth/email-verification/status',
      queryParameters: {'token': token},
    );
    final map = data as Map<String, dynamic>;
    return EmailVerificationInfo(
      fullName: (map['fullName'] as String?) ?? '',
      email: (map['email'] as String?) ?? '',
      expiresAt: DateTime.parse(map['expiresAt'] as String),
    );
  }

  Future<void> confirmEmailVerification({required String token}) async {
    await _apiClient.post(
      '/auth/email-verification/confirm',
      body: {'token': token},
    );
  }

  Future<void> requestPasswordReset({required String email}) async {
    await _apiClient.post(
      '/auth/password-reset/request',
      body: {'email': email},
    );
  }

  Future<PasswordResetInfo> getPasswordResetStatus(String token) async {
    final data = await _apiClient.get(
      '/auth/password-reset/status',
      queryParameters: {'token': token},
    );
    final map = data as Map<String, dynamic>;
    return PasswordResetInfo(
      fullName: (map['fullName'] as String?) ?? '',
      email: (map['email'] as String?) ?? '',
      expiresAt: DateTime.parse(map['expiresAt'] as String),
    );
  }

  Future<void> completePasswordReset({
    required String token,
    required String password,
  }) async {
    await _apiClient.post(
      '/auth/password-reset/complete',
      body: {'token': token, 'password': password},
    );
  }

  Future<User> login(String email, String password) async {
    if (ApiConfig.useMockApi && kDebugMode) {
      return _mockLogin(email, password);
    }

    try {
      final dynamic data = await _apiClient.post(
        '/auth/login',
        body: {'email': email, 'password': password},
      );

      final Map<String, dynamic> mapped = _mapLoginResponse(data);
      return User.fromJson(mapped);
    } on ApiException catch (e) {
      throw Exception(_mapLoginError(e));
    } on FormatException {
      throw Exception(
        'La respuesta del servidor no tiene el formato esperado.',
      );
    }
  }

  Future<User> refreshSession() async {
    final dynamic data = await _apiClient.post('/auth/refresh');
    final Map<String, dynamic> mapped = _mapLoginResponse(data);
    return User.fromJson(mapped);
  }

  Future<void> changePassword(
    String token, {
    required String currentPassword,
    required String newPassword,
  }) async {
    await _apiClient.post(
      '/auth/change-password',
      headers: {'Authorization': 'Bearer $token'},
      body: {'currentPassword': currentPassword, 'newPassword': newPassword},
    );
  }

  Future<void> logout({String? token}) async {
    await _apiClient.post(
      '/auth/logout',
      headers: token == null || token.isEmpty
          ? null
          : {'Authorization': 'Bearer $token'},
    );
  }

  Map<String, dynamic> _mapLoginResponse(dynamic responseData) {
    if (responseData is! Map<String, dynamic>) {
      throw const FormatException('Respuesta invalida.');
    }

    // Soporta dos formatos comunes:
    // 1) { id, name, email, role, token }
    // 2) { user: { id, name, email, role }, token }
    if (responseData['user'] is Map<String, dynamic>) {
      final Map<String, dynamic> user = Map<String, dynamic>.from(
        responseData['user'] as Map,
      );
      user['token'] = responseData['token'];
      return user;
    }

    return responseData;
  }

  Future<User> _mockLogin(String email, String password) async {
    await Future<void>.delayed(const Duration(milliseconds: 600));

    if (password != '1234') {
      throw Exception('Credenciales invalidas.');
    }

    if (email.toLowerCase() == 'admin@navalgo.com') {
      return User(
        id: 1,
        name: 'Admin Navalgo',
        email: email,
        role: 'ADMIN',
        token: 'mock-admin-jwt-token',
      );
    }

    if (email.toLowerCase() == 'worker@navalgo.com') {
      return User(
        id: 2,
        name: 'Worker Navalgo',
        email: email,
        role: 'WORKER',
        token: 'mock-worker-jwt-token',
      );
    }

    if (email.toLowerCase() == 'comercial@navalgo.com') {
      return User(
        id: 3,
        name: 'Comercial Navalgo',
        email: email,
        role: 'COMERCIAL',
        token: 'mock-commercial-jwt-token',
      );
    }

    if (email.toLowerCase() == 'cliente@navalgo.com') {
      return User(
        id: 4,
        name: 'Cliente Navalgo',
        email: email,
        role: 'CLIENT',
        ownerId: 1,
        token: 'mock-client-jwt-token',
      );
    }

    throw Exception('Usuario no encontrado en modo mock.');
  }

  String _mapLoginError(ApiException exception) {
    final serverMessage = _extractServerMessage(exception.details);

    if (exception.statusCode == 400) {
      if (serverMessage == 'Credenciales invalidas') {
        return 'Correo o contrasena incorrectos.';
      }
      if (serverMessage == 'Usuario inactivo') {
        return 'Tu cuenta esta desactivada. Contacta con el administrador.';
      }
    }

    return serverMessage ?? 'No se pudo iniciar sesion en este momento.';
  }

  String? _extractServerMessage(String? rawDetails) {
    if (rawDetails == null || rawDetails.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(rawDetails);
      if (decoded is Map<String, dynamic>) {
        final value = decoded['message'];
        if (value is String && value.isNotEmpty) {
          return value;
        }
      }
    } catch (_) {
      return null;
    }

    return null;
  }
}

class RegistrationInvitationInfo {
  const RegistrationInvitationInfo({
    required this.fullName,
    required this.email,
    required this.expiresAt,
  });

  final String fullName;
  final String email;
  final DateTime expiresAt;
}

class EmailVerificationInfo {
  const EmailVerificationInfo({
    required this.fullName,
    required this.email,
    required this.expiresAt,
  });

  final String fullName;
  final String email;
  final DateTime expiresAt;
}

class PasswordResetInfo {
  const PasswordResetInfo({
    required this.fullName,
    required this.email,
    required this.expiresAt,
  });

  final String fullName;
  final String email;
  final DateTime expiresAt;
}
