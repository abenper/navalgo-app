class ApiException implements Exception {
  ApiException(this.message, {this.statusCode, this.details});

  final String message;
  final int? statusCode;
  final String? details;

  @override
  String toString() {
    final code = statusCode != null ? ' (HTTP $statusCode)' : '';
    final extra = details != null && details!.isNotEmpty ? ' - $details' : '';
    return '$message$code$extra';
  }
}
