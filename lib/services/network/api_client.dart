import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_exception.dart';

class ApiClient {
  ApiClient({required this.baseUrl, http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  static Future<void> Function(String message)? _sessionExpiredHandler;

  static void configureSessionExpiredHandler(
    Future<void> Function(String message)? handler,
  ) {
    _sessionExpiredHandler = handler;
  }

  final String baseUrl;
  final http.Client _httpClient;

  Future<dynamic> get(
    String path, {
    Map<String, String>? headers,
    Map<String, dynamic>? queryParameters,
  }) async {
    await _ensureSessionIsValid(headers);

    final uri = Uri.parse('$baseUrl$path').replace(
      queryParameters: queryParameters?.map(
        (key, value) => MapEntry(key, value.toString()),
      ),
    );

    late final http.Response response;
    try {
      response = await _httpClient
          .get(uri, headers: _buildHeaders(headers))
          .timeout(const Duration(seconds: 12));
    } on Exception catch (e) {
      throw ApiException('No se pudo conectar con el servidor', details: '$e');
    }

    return _decodeResponse(response);
  }

  Future<dynamic> post(
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) async {
    await _ensureSessionIsValid(headers);

    final uri = Uri.parse('$baseUrl$path');

    late final http.Response response;
    try {
      response = await _httpClient
          .post(
            uri,
            headers: _buildHeaders(headers),
            body: jsonEncode(body ?? <String, dynamic>{}),
          )
          .timeout(const Duration(seconds: 12));
    } on Exception catch (e) {
      throw ApiException('No se pudo conectar con el servidor', details: '$e');
    }

    return _decodeResponse(response);
  }

  Future<dynamic> patch(
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) async {
    await _ensureSessionIsValid(headers);

    final uri = Uri.parse('$baseUrl$path');

    late final http.Response response;
    try {
      response = await _httpClient
          .patch(
            uri,
            headers: _buildHeaders(headers),
            body: jsonEncode(body ?? <String, dynamic>{}),
          )
          .timeout(const Duration(seconds: 12));
    } on Exception catch (e) {
      throw ApiException('No se pudo conectar con el servidor', details: '$e');
    }

    return _decodeResponse(response);
  }

  Future<dynamic> put(
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) async {
    await _ensureSessionIsValid(headers);

    final uri = Uri.parse('$baseUrl$path');

    late final http.Response response;
    try {
      response = await _httpClient
          .put(
            uri,
            headers: _buildHeaders(headers),
            body: jsonEncode(body ?? <String, dynamic>{}),
          )
          .timeout(const Duration(seconds: 12));
    } on Exception catch (e) {
      throw ApiException('No se pudo conectar con el servidor', details: '$e');
    }

    return _decodeResponse(response);
  }

  Future<dynamic> delete(
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
  }) async {
    await _ensureSessionIsValid(headers);

    final uri = Uri.parse('$baseUrl$path');

    late final http.Response response;
    try {
      response = await _httpClient
          .delete(
            uri,
            headers: _buildHeaders(headers),
            body: body == null ? null : jsonEncode(body),
          )
          .timeout(const Duration(seconds: 12));
    } on Exception catch (e) {
      throw ApiException('No se pudo conectar con el servidor', details: '$e');
    }

    return _decodeResponse(response);
  }

  Map<String, String> _buildHeaders(Map<String, String>? headers) {
    return {'Content-Type': 'application/json', ...?headers};
  }

  dynamic _decodeResponse(http.Response response) {
    final String rawBody = response.body;
    final token = extractBearerToken(response.request?.headers);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      if (response.statusCode == 401 && token != null) {
        unawaited(_notifySessionExpired());
        throw ApiException.sessionExpired();
      }

      if (response.statusCode == 403 && token != null && isJwtExpired(token)) {
        unawaited(_notifySessionExpired());
        throw ApiException.sessionExpired();
      }

      throw ApiException(
        'Error en la respuesta del servidor',
        statusCode: response.statusCode,
        details: rawBody,
      );
    }

    if (rawBody.isEmpty) {
      return <String, dynamic>{};
    }

    try {
      return jsonDecode(rawBody);
    } on FormatException {
      throw ApiException(
        'El servidor devolvio un JSON invalido',
        statusCode: response.statusCode,
        details: rawBody,
      );
    }
  }

  Future<void> _ensureSessionIsValid(Map<String, String>? headers) async {
    final token = extractBearerToken(headers);
    if (token == null || token.isEmpty) {
      return;
    }

    if (isJwtExpired(token)) {
      await _notifySessionExpired();
      throw ApiException.sessionExpired();
    }
  }

  static String? extractBearerToken(Map<String, String>? headers) {
    if (headers == null || headers.isEmpty) {
      return null;
    }

    final authorization = headers.entries
        .firstWhere(
          (entry) => entry.key.toLowerCase() == 'authorization',
          orElse: () => const MapEntry('', ''),
        )
        .value;

    if (!authorization.startsWith('Bearer ')) {
      return null;
    }

    final token = authorization.substring(7).trim();
    return token.isEmpty ? null : token;
  }

  static bool isJwtExpired(String token) {
    try {
      final parts = token.split('.');
      if (parts.length < 2) {
        return false;
      }

      final payload = utf8.decode(
        base64Url.decode(base64Url.normalize(parts[1])),
      );
      final decoded = jsonDecode(payload);
      if (decoded is! Map<String, dynamic>) {
        return false;
      }

      final rawExp = decoded['exp'];
      final expSeconds = rawExp is num
          ? rawExp.toInt()
          : int.tryParse('$rawExp');
      if (expSeconds == null) {
        return false;
      }

      final expiry = DateTime.fromMillisecondsSinceEpoch(
        expSeconds * 1000,
        isUtc: true,
      );
      return !expiry.isAfter(DateTime.now().toUtc());
    } catch (_) {
      return false;
    }
  }

  static Future<ApiException?> maybeHandleSessionExpired({
    required String token,
    required int statusCode,
  }) async {
    final expired = isJwtExpired(token);
    final shouldExpire = statusCode == 401 || (statusCode == 403 && expired);

    if (!shouldExpire) {
      return null;
    }

    await _notifySessionExpired();
    return ApiException.sessionExpired();
  }

  static Future<void> _notifySessionExpired() async {
    final handler = _sessionExpiredHandler;
    if (handler == null) {
      return;
    }
    await handler('Tu sesión ha expirado. Inicia sesión de nuevo.');
  }
}
