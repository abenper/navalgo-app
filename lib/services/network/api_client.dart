import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'api_exception.dart';
import 'http_client_factory.dart';

class ApiClient {
  ApiClient({required this.baseUrl, http.Client? httpClient})
    : _httpClient = httpClient ?? createHttpClient();

  static Future<void> Function(String message)? _sessionExpiredHandler;
  static Future<String?> Function()? _accessTokenRefreshHandler;
  static Future<String?>? _refreshInFlight;
  static const _refreshCookieName = 'navalgo_refresh_token';
  static const _refreshCookieStorageKey = 'auth_refresh_cookie';
  static String? _cachedRefreshCookie;
  static bool _refreshCookieLoaded = false;

  static void configureSessionExpiredHandler(
    Future<void> Function(String message)? handler,
  ) {
    _sessionExpiredHandler = handler;
  }

  static void configureAccessTokenRefreshHandler(
    Future<String?> Function()? handler,
  ) {
    _accessTokenRefreshHandler = handler;
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
      await _ensureRefreshCookieLoaded();
      response = await _httpClient
          .get(uri, headers: _buildHeaders(headers, uri: uri))
          .timeout(const Duration(seconds: 12));
    } on Exception catch (e) {
      throw ApiException('No se pudo conectar con el servidor', details: '$e');
    }

    await _storeRefreshCookieFromHeaders(response.headers);
    return _decodeResponse(response);
  }

  Future<Uint8List> getBytes(
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

    return _getBytesFromUri(uri, headers);
  }

  Future<Uint8List> getBytesFromAbsoluteUrl(
    String absoluteUrl, {
    Map<String, String>? headers,
  }) async {
    await _ensureSessionIsValid(headers);

    final uri = Uri.parse(absoluteUrl);
    return _getBytesFromUri(uri, headers);
  }

  Future<Uint8List> _getBytesFromUri(
    Uri uri,
    Map<String, String>? headers,
  ) async {
    late final http.Response response;
    try {
      await _ensureRefreshCookieLoaded();
      response = await _httpClient
          .get(uri, headers: _buildHeaders(headers, uri: uri))
          .timeout(const Duration(seconds: 30));
    } on Exception catch (e) {
      throw ApiException('No se pudo conectar con el servidor', details: '$e');
    }

    await _storeRefreshCookieFromHeaders(response.headers);
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
        details: response.body,
      );
    }
    return response.bodyBytes;
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
      await _ensureRefreshCookieLoaded();
      response = await _httpClient
          .post(
            uri,
            headers: _buildHeaders(headers, uri: uri),
            body: jsonEncode(body ?? <String, dynamic>{}),
          )
          .timeout(const Duration(seconds: 12));
    } on Exception catch (e) {
      throw ApiException('No se pudo conectar con el servidor', details: '$e');
    }

    await _storeRefreshCookieFromHeaders(response.headers);
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
      await _ensureRefreshCookieLoaded();
      response = await _httpClient
          .patch(
            uri,
            headers: _buildHeaders(headers, uri: uri),
            body: jsonEncode(body ?? <String, dynamic>{}),
          )
          .timeout(const Duration(seconds: 12));
    } on Exception catch (e) {
      throw ApiException('No se pudo conectar con el servidor', details: '$e');
    }

    await _storeRefreshCookieFromHeaders(response.headers);
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
      await _ensureRefreshCookieLoaded();
      response = await _httpClient
          .put(
            uri,
            headers: _buildHeaders(headers, uri: uri),
            body: jsonEncode(body ?? <String, dynamic>{}),
          )
          .timeout(const Duration(seconds: 12));
    } on Exception catch (e) {
      throw ApiException('No se pudo conectar con el servidor', details: '$e');
    }

    await _storeRefreshCookieFromHeaders(response.headers);
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
      await _ensureRefreshCookieLoaded();
      response = await _httpClient
          .delete(
            uri,
            headers: _buildHeaders(headers, uri: uri),
            body: body == null ? null : jsonEncode(body),
          )
          .timeout(const Duration(seconds: 12));
    } on Exception catch (e) {
      throw ApiException('No se pudo conectar con el servidor', details: '$e');
    }

    await _storeRefreshCookieFromHeaders(response.headers);
    return _decodeResponse(response);
  }

  Map<String, String> _buildHeaders(Map<String, String>? headers, {Uri? uri}) {
    final builtHeaders = {'Content-Type': 'application/json', ...?headers};
    final refreshCookie = _cachedRefreshCookie;
    if (refreshCookie != null &&
        refreshCookie.isNotEmpty &&
        _shouldSendRefreshCookie(uri) &&
        !builtHeaders.keys.any((key) => key.toLowerCase() == 'cookie')) {
      builtHeaders['Cookie'] = '$_refreshCookieName=$refreshCookie';
    }
    return builtHeaders;
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
      final refreshedToken = await _refreshExpiredAccessToken();
      if (refreshedToken != null && refreshedToken.isNotEmpty) {
        headers?['Authorization'] = 'Bearer $refreshedToken';
        return;
      }
      await _notifySessionExpired();
      throw ApiException.sessionExpired();
    }
  }

  static Future<String?> _refreshExpiredAccessToken() async {
    final handler = _accessTokenRefreshHandler;
    if (handler == null) {
      return null;
    }

    final currentRefresh = _refreshInFlight;
    if (currentRefresh != null) {
      return currentRefresh;
    }

    final refreshFuture = handler();
    _refreshInFlight = refreshFuture;
    try {
      return await refreshFuture;
    } finally {
      if (identical(_refreshInFlight, refreshFuture)) {
        _refreshInFlight = null;
      }
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

  static bool _shouldSendRefreshCookie(Uri? uri) {
    if (uri == null) {
      return true;
    }
    return uri.path.startsWith('/api/');
  }

  static Future<void> _ensureRefreshCookieLoaded() async {
    if (_refreshCookieLoaded) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    _cachedRefreshCookie = prefs.getString(_refreshCookieStorageKey);
    _refreshCookieLoaded = true;
  }

  static Future<void> _storeRefreshCookieFromHeaders(
    Map<String, String> headers,
  ) async {
    final rawSetCookie = headers.entries
        .firstWhere(
          (entry) => entry.key.toLowerCase() == 'set-cookie',
          orElse: () => const MapEntry('', ''),
        )
        .value;
    if (rawSetCookie.isEmpty || !rawSetCookie.contains(_refreshCookieName)) {
      return;
    }

    final match = RegExp(
      '$_refreshCookieName=([^;]*)',
      caseSensitive: false,
    ).firstMatch(rawSetCookie);
    if (match == null) {
      return;
    }

    final value = match.group(1)?.trim() ?? '';
    final shouldClear =
        value.isEmpty || rawSetCookie.toLowerCase().contains('max-age=0');
    final prefs = await SharedPreferences.getInstance();
    if (shouldClear) {
      _cachedRefreshCookie = null;
      await prefs.remove(_refreshCookieStorageKey);
      return;
    }

    _cachedRefreshCookie = value;
    await prefs.setString(_refreshCookieStorageKey, value);
  }
}
