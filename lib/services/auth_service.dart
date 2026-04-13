import 'package:http/http.dart' as http;
import '../models/user.dart'; // Tu modelo de usuario
import '../config/api_config.dart';
import 'network/api_client.dart';
import 'network/api_exception.dart';

class AuthService {
  AuthService({ApiClient? apiClient, http.Client? httpClient})
    : _apiClient =
          apiClient ?? ApiClient(baseUrl: ApiConfig.baseUrl, httpClient: httpClient);

  final ApiClient _apiClient;

  Future<User> login(String email, String password) async {
    if (ApiConfig.useMockApi) {
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
      throw Exception('Fallo al iniciar sesion: ${e.message}');
    } on FormatException {
      throw Exception('La respuesta del servidor no tiene el formato esperado.');
    }
  }

  Future<void> changePassword(
    String token, {
    required String currentPassword,
    required String newPassword,
  }) async {
    await _apiClient.post(
      '/auth/change-password',
      headers: {'Authorization': 'Bearer $token'},
      body: {
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      },
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
      final Map<String, dynamic> user =
          Map<String, dynamic>.from(responseData['user'] as Map);
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

    throw Exception('Usuario no encontrado en modo mock.');
  }
}