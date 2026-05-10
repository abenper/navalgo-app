import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../config/api_config.dart';
import '../models/budget.dart';
import '../utils/media_url.dart' as media;
import 'network/api_client.dart';

class BudgetService {
  BudgetService({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient(baseUrl: ApiConfig.baseUrl);

  final ApiClient _apiClient;

  Future<List<Budget>> getBudgets(String token) async {
    final data = await _apiClient.get(
      '/budgets',
      headers: {'Authorization': 'Bearer $token'},
    );
    if (data is! List) {
      return <Budget>[];
    }
    return data.whereType<Map<String, dynamic>>().map(Budget.fromJson).toList();
  }

  Future<Budget> createBudget(
    String token, {
    int? ownerId,
    int? vesselId,
    String? contactEmail,
    String? newClientName,
    String? newVesselName,
    required String title,
    String? description,
    double? amount,
    String currency = 'EUR',
    required String pdfUrl,
  }) async {
    final data = await _apiClient.post(
      '/budgets',
      headers: {'Authorization': 'Bearer $token'},
      body: {
        'ownerId': ownerId,
        'vesselId': vesselId,
        'contactEmail': contactEmail,
        'newClientName': newClientName,
        'newVesselName': newVesselName,
        'title': title,
        'description': description,
        'amount': amount,
        'currency': currency,
        'pdfUrl': pdfUrl,
      },
    );
    return Budget.fromJson(data as Map<String, dynamic>);
  }

  Future<Budget> updateBudgetDraft(
    String token, {
    required int budgetId,
    int? ownerId,
    String? contactEmail,
    String? newClientName,
    required String title,
    String? description,
    double? amount,
    String currency = 'EUR',
    required String pdfUrl,
  }) async {
    final data = await _apiClient.put(
      '/budgets/$budgetId',
      headers: {'Authorization': 'Bearer $token'},
      body: {
        'ownerId': ownerId,
        'contactEmail': contactEmail,
        'newClientName': newClientName,
        'title': title,
        'description': description,
        'amount': amount,
        'currency': currency,
        'pdfUrl': pdfUrl,
      },
    );
    return Budget.fromJson(data as Map<String, dynamic>);
  }

  Future<Uint8List> downloadBudgetPdf(String token, String pdfUrl) async {
    final resolvedUrl = media.resolveMediaUrl(pdfUrl);
    return _apiClient.getBytesFromAbsoluteUrl(
      resolvedUrl,
      headers: {'Authorization': 'Bearer $token'},
    );
  }

  Future<void> deleteBudget(String token, {required int budgetId}) async {
    await _apiClient.delete(
      '/budgets/$budgetId',
      headers: {'Authorization': 'Bearer $token'},
    );
  }

  Future<Budget> updateBudgetStatus(
    String token, {
    required int budgetId,
    required String status,
    String? clientObservations,
  }) async {
    final data = await _apiClient.patch(
      '/budgets/$budgetId/status',
      headers: {'Authorization': 'Bearer $token'},
      body: {'status': status, 'clientObservations': clientObservations},
    );
    return Budget.fromJson(data as Map<String, dynamic>);
  }

  Future<Budget> assignBudgetVessel(
    String token, {
    required int budgetId,
    required int vesselId,
  }) async {
    final data = await _apiClient.patch(
      '/budgets/$budgetId/vessel',
      headers: {'Authorization': 'Bearer $token'},
      body: {'vesselId': vesselId},
    );
    return Budget.fromJson(data as Map<String, dynamic>);
  }

  Future<UploadedBudgetDocument> uploadBudgetPdf(
    String token, {
    int? ownerId,
    int? vesselId,
    String? ownerName,
    String? vesselName,
    required String fileName,
    required List<int> bytes,
    String mimeType = 'application/pdf',
  }) async {
    await _ensureSessionIsValid(token);

    final uri = Uri.parse('${ApiConfig.baseUrl}/budgets/uploads');
    final request = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer $token';

    if (ownerId != null) request.fields['ownerId'] = '$ownerId';
    if (vesselId != null) request.fields['vesselId'] = '$vesselId';
    if (ownerName != null) request.fields['ownerName'] = ownerName;
    if (vesselName != null) request.fields['vesselName'] = vesselName;

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
        'Error subiendo PDF (${response.statusCode}): ${response.body}',
      );
    }

    return UploadedBudgetDocument.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  MediaType _parseMediaType(String mimeType) {
    final parts = mimeType.split('/');
    if (parts.length == 2) {
      return MediaType(parts[0], parts[1]);
    }
    return MediaType('application', 'pdf');
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
