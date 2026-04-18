import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../config/api_config.dart';
import '../models/worker_profile.dart';
import 'network/api_client.dart';

class WorkerPhotoService {
  Future<WorkerProfile> uploadPhoto(
    String token, {
    required int workerId,
    required String fileName,
    required List<int> bytes,
    required String mimeType,
  }) async {
    await _ensureSessionIsValid(token);

    final uri = Uri.parse('${ApiConfig.baseUrl}/workers/$workerId/photo');
    final request = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer $token';

    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: fileName,
        contentType: _parseMediaType(mimeType),
      ),
    );

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final sessionError = await ApiClient.maybeHandleSessionExpired(
        token: token,
        statusCode: response.statusCode,
      );
      if (sessionError != null) {
        throw sessionError;
      }

      final message = _extractErrorMessage(response.body);
      throw Exception(
        'Error subiendo foto de perfil (${response.statusCode}): $message',
      );
    }

    return WorkerProfile.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<void> _ensureSessionIsValid(String token) async {
    if (!ApiClient.isJwtExpired(token)) {
      return;
    }

    final sessionError = await ApiClient.maybeHandleSessionExpired(
      token: token,
      statusCode: 403,
    );
    if (sessionError != null) {
      throw sessionError;
    }
  }

  MediaType _parseMediaType(String mimeType) {
    final parts = mimeType.split('/');
    if (parts.length == 2) return MediaType(parts[0], parts[1]);
    return MediaType('application', 'octet-stream');
  }

  String _extractErrorMessage(String responseBody) {
    try {
      final decoded = jsonDecode(responseBody);
      if (decoded is Map<String, dynamic>) {
        final message = decoded['message']?.toString().trim();
        if (message != null && message.isNotEmpty) {
          return message;
        }
      }
    } catch (_) {}

    final fallback = responseBody.trim();
    return fallback.isEmpty ? 'Error desconocido del servidor' : fallback;
  }
}
