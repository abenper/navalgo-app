import 'dart:convert';

class ApiException implements Exception {
  ApiException(
    this.message, {
    this.statusCode,
    this.details,
    this.isSessionExpired = false,
  });

  factory ApiException.sessionExpired([
    String message = 'Tu sesión ha expirado. Inicia sesión de nuevo.',
  ]) {
    return ApiException(message, statusCode: 401, isSessionExpired: true);
  }

  final String message;
  final int? statusCode;
  final String? details;
  final bool isSessionExpired;

  String? get serverMessage {
    final raw = details?.trim();
    if (raw == null || raw.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        final message = decoded['message']?.toString().trim();
        if (message != null && message.isNotEmpty) {
          return message;
        }
      }
    } catch (_) {
      return raw;
    }

    return raw;
  }

  @override
  String toString() {
    if (isSessionExpired) {
      return message;
    }

    final code = statusCode != null ? ' (HTTP $statusCode)' : '';
    final resolvedDetails = serverMessage;
    final extra = resolvedDetails != null && resolvedDetails.isNotEmpty
        ? ' - $resolvedDetails'
        : '';
    return '$message$code$extra';
  }
}
