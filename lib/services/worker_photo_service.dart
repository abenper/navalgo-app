import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../config/api_config.dart';
import '../models/worker_profile.dart';

class WorkerPhotoService {
  Future<WorkerProfile> uploadPhoto(
    String token, {
    required int workerId,
    required String fileName,
    required List<int> bytes,
    required String mimeType,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/workers/$workerId/photo');
    final request = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer $token';

    request.files.add(http.MultipartFile.fromBytes(
      'file',
      bytes,
      filename: fileName,
      contentType: _parseMediaType(mimeType),
    ));

    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
          'Error subiendo foto de perfil (${response.statusCode}): ${response.body}');
    }

    return WorkerProfile.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  MediaType _parseMediaType(String mimeType) {
    final parts = mimeType.split('/');
    if (parts.length == 2) return MediaType(parts[0], parts[1]);
    return MediaType('application', 'octet-stream');
  }
}
