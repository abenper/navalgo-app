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

  String get userMessage {
    if (isSessionExpired) {
      return message;
    }

    final normalized = (serverMessage ?? details ?? '').trim().toLowerCase();
    if (normalized.isNotEmpty) {
      if (normalized.contains('ya existe una cuenta con ese correo')) {
        return 'Ya existe una cuenta con ese correo electrónico.';
      }
      if (normalized.contains('ya tiene una cuenta asociada')) {
        return 'Ese cliente ya tiene una cuenta asociada.';
      }
      if (normalized.contains('enlace de verificacion no es valido') ||
          normalized.contains('enlace de activacion no es valido') ||
          normalized.contains('ha caducado')) {
        return 'El enlace ya no es válido o ha caducado.';
      }
      if (normalized.contains('embarcacion') &&
          (normalized.contains('parte') ||
              normalized.contains('presupuesto') ||
              normalized.contains('asociad') ||
              normalized.contains('relacionad') ||
              normalized.contains('constraint') ||
              normalized.contains('foreign key') ||
              normalized.contains('datos'))) {
        return 'No se puede borrar la embarcación porque tiene datos asociados. Contacta con la empresa encargada para gestionarlo.';
      }
      if (normalized.contains('credenciales invalidas')) {
        return 'Correo o contraseña incorrectos.';
      }
      if (normalized.contains('debes confirmar tu correo electronico')) {
        return 'Debes confirmar tu correo electrónico antes de iniciar sesión.';
      }
    }

    if (statusCode != null && statusCode! >= 500) {
      return 'Ha ocurrido un error interno. Inténtalo de nuevo más tarde.';
    }
    if (statusCode == 401 || statusCode == 403) {
      return 'No tienes permiso para realizar esta acción.';
    }
    if (statusCode == 404) {
      return 'No se encontró la información solicitada.';
    }
    if (statusCode == 400 || statusCode == 409) {
      return 'No se pudo completar la solicitud.';
    }

    return message;
  }

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
    return userMessage;
  }
}
