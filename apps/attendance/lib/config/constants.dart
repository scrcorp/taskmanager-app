/// Attendance 앱 전역 상수.
///
/// API base URL은 빌드 시 `--dart-define=API_BASE_URL=...`로 주입.
/// 미지정 시 로컬 개발 서버(`localhost:58000`)를 기본값으로 사용.
class AppConstants {
  static const String appName = 'HTM Attendance';

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:58000/api/v1',
  );
}
