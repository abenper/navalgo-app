import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_exception.dart';

class ApiClient {
  ApiClient({required this.baseUrl, http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  final String baseUrl;
  final http.Client _httpClient;

  Future<dynamic> get(
    String path, {
    Map<String, String>? headers,
    Map<String, dynamic>? queryParameters,
  }) async {
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

  Map<String, String> _buildHeaders(Map<String, String>? headers) {
    return {
      'Content-Type': 'application/json',
      ...?headers,
    };
  }

  dynamic _decodeResponse(http.Response response) {
    final String rawBody = response.body;

    if (response.statusCode < 200 || response.statusCode >= 300) {
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
}
