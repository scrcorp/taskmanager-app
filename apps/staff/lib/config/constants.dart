/// 앱 전역 상수 정의
///
/// API 기본 URL 등 환경별로 달라질 수 있는 설정값을 관리한다.
/// 빌드 시 --dart-define=API_BASE_URL=... 으로 오버라이드 가능.
class AppConstants {
  /// 앱 이름 (타이틀바 등에 사용)
  static const String appName = 'HTM';

  /// 백엔드 API 기본 URL
  ///
  /// 빌드 환경변수 `API_BASE_URL`로 주입.
  /// 미지정 시 로컬 개발서버(`localhost:58000`)를 기본값으로 사용.
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:58000/api/v1',
  );

  /// 공개 사이트(홈페이지) base URL
  ///
  /// "What's New" 진입 시 홈페이지 `/changelog` 로 이동하는 데 사용한다.
  /// 빌드 환경변수 `SITE_BASE_URL`로 주입 (예: prod `https://hermesops.site`,
  /// staging `https://stg.hermesops.site`). 미지정 시 로컬 콘솔/사이트
  /// 개발서버(`localhost:53000`)를 기본값으로 사용.
  static const String siteBaseUrl = String.fromEnvironment(
    'SITE_BASE_URL',
    defaultValue: 'http://localhost:53000',
  );

  /// 홈페이지 공개 changelog(What's New) 전체 URL.
  static String get changelogUrl => '$siteBaseUrl/changelog';

  /// 배포 환경 — 빌드 환경변수 `APP_ENV` ('production' | 'staging' | 미지정=로컬).
  static const String appEnv = String.fromEnvironment('APP_ENV');

  /// 운영 환경인가. 진단용 UI(테스트 푸시 발송 등)를 숨기는 기준이다.
  ///
  /// 서버도 같은 기준으로 진단 엔드포인트를 등록하지 않는다. 클라이언트에서만
  /// 숨기면 버튼은 사라져도 API 는 열려 있게 되므로 양쪽 다 막아야 한다.
  static const bool isProduction = appEnv == 'production';
}
