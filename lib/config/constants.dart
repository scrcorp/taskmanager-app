class AppConstants {
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8000/api/v1',
  );
  static const String appName = 'TaskManager';

  /// Mock mode: default true for development without server
  /// To connect real server: flutter run --dart-define=USE_MOCK=false
  static const bool useMock = bool.fromEnvironment('USE_MOCK', defaultValue: true);
}
