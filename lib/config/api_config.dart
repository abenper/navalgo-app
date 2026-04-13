class ApiConfig {
  ApiConfig._();

  // Cambia por --dart-define=API_BASE_URL=http://tu-host:8080/api
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8080/api',
  );

  // true: usa respuestas simuladas en cliente
  // false: consume tu API Spring Boot real
  static const bool useMockApi = bool.fromEnvironment(
    'USE_MOCK_API',
    defaultValue: true,
  );
}
