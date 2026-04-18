import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../config/api_config.dart';
import '../models/work_order.dart';
import 'network/api_client.dart';

class WorkOrderMediaService {
  /// Upload one file to /work-orders/uploads (web-only, enforced by backend).
  Future<WorkOrderAttachmentItem> uploadMedia(
    String token, {
    required String fileName,
    required List<int> bytes,
    required String mimeType,
    double? latitude,
    double? longitude,
    DateTime? capturedAt,
    String? ownerName,
    String? vesselName,
    DateTime? workOrderDate,
  }) async {
    await _ensureSessionIsValid(token);

    final uri = Uri.parse('${ApiConfig.baseUrl}/work-orders/uploads');
    final request = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer $token'
      ..headers['X-Client-Platform'] = 'web';

    if (latitude != null) request.fields['latitude'] = latitude.toString();
    if (longitude != null) request.fields['longitude'] = longitude.toString();
    if (capturedAt != null) {
      request.fields['capturedAt'] = capturedAt.toUtc().toIso8601String();
    }
    if (ownerName != null && ownerName.trim().isNotEmpty) {
      request.fields['ownerName'] = ownerName.trim();
    }
    if (vesselName != null && vesselName.trim().isNotEmpty) {
      request.fields['vesselName'] = vesselName.trim();
    }
    if (workOrderDate != null) {
      final y = workOrderDate.year.toString().padLeft(4, '0');
      final m = workOrderDate.month.toString().padLeft(2, '0');
      final d = workOrderDate.day.toString().padLeft(2, '0');
      request.fields['workOrderDate'] = '$y-$m-$d';
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
      final sessionError = await ApiClient.maybeHandleSessionExpired(
        token: token,
        statusCode: response.statusCode,
      );
      if (sessionError != null) {
        throw sessionError;
      }

      throw Exception(
        'Error subiendo multimedia (${response.statusCode}): ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return WorkOrderAttachmentItem.fromJson(decoded);
  }

  Future<WorkOrder> attachToWorkOrder(
    String token, {
    required int workOrderId,
    required String fileName,
    required List<int> bytes,
    required String mimeType,
    double? latitude,
    double? longitude,
    DateTime? capturedAt,
  }) async {
    await _ensureSessionIsValid(token);

    final uri = Uri.parse(
      '${ApiConfig.baseUrl}/work-orders/$workOrderId/attachments',
    );
    final request = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer $token';

    if (latitude != null) request.fields['latitude'] = latitude.toString();
    if (longitude != null) request.fields['longitude'] = longitude.toString();
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
      final sessionError = await ApiClient.maybeHandleSessionExpired(
        token: token,
        statusCode: response.statusCode,
      );
      if (sessionError != null) {
        throw sessionError;
      }

      throw Exception(
        'Error adjuntando multimedia (${response.statusCode}): ${response.body}',
      );
    }

    return WorkOrder.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  /// Sign a work order: sends the drawn signature + optional proof attachments.
  /// Works from both web and mobile (no platform restriction).
  Future<WorkOrder> signWorkOrder(
    String token, {
    required int workOrderId,
    required String signatureFileName,
    required List<int> signatureBytes,
    required String signatureMimeType,
    List<ProofFile> proofFiles = const [],
    double? latitude,
    double? longitude,
  }) async {
    await _ensureSessionIsValid(token);

    final uri = Uri.parse('${ApiConfig.baseUrl}/work-orders/$workOrderId/sign');
    final request = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer $token';

    if (latitude != null) request.fields['latitude'] = latitude.toString();
    if (longitude != null) request.fields['longitude'] = longitude.toString();

    request.files.add(
      http.MultipartFile.fromBytes(
        'signatureFile',
        signatureBytes,
        filename: signatureFileName,
        contentType: _parseMediaType(signatureMimeType),
      ),
    );

    for (final proof in proofFiles) {
      request.files.add(
        http.MultipartFile.fromBytes(
          'proofFile',
          proof.bytes,
          filename: proof.fileName,
          contentType: _parseMediaType(proof.mimeType),
        ),
      );
    }

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

      throw Exception(
        'Error firmando parte (${response.statusCode}): ${response.body}',
      );
    }

    return WorkOrder.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  MediaType _parseMediaType(String mimeType) {
    final parts = mimeType.split('/');
    if (parts.length == 2) return MediaType(parts[0], parts[1]);
    return MediaType('application', 'octet-stream');
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
}

class ProofFile {
  const ProofFile({
    required this.fileName,
    required this.bytes,
    required this.mimeType,
  });

  final String fileName;
  final List<int> bytes;
  final String mimeType;
}
