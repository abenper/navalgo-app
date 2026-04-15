import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../config/api_config.dart';
import '../models/work_order.dart';

class WorkOrderMediaService {
  Future<WorkOrderAttachmentItem> uploadMedia(
    String token, {
    required String fileName,
    required List<int> bytes,
    required String mimeType,
    double? latitude,
    double? longitude,
    DateTime? capturedAt,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/work-orders/uploads');
    final request = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer $token'
      ..headers['X-Client-Platform'] = 'web';

    if (latitude != null) {
      request.fields['latitude'] = latitude.toString();
    }
    if (longitude != null) {
      request.fields['longitude'] = longitude.toString();
    }
    if (capturedAt != null) {
      request.fields['capturedAt'] = capturedAt.toUtc().toIso8601String();
    }

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
      throw Exception('Error subiendo multimedia (${response.statusCode}): ${response.body}');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return WorkOrderAttachmentItem.fromJson(decoded);
  }

  MediaType _parseMediaType(String mimeType) {
    final parts = mimeType.split('/');
    if (parts.length == 2) {
      return MediaType(parts[0], parts[1]);
    }
    return MediaType('application', 'octet-stream');
  }
}
