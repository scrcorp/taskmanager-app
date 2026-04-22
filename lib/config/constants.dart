/// 앱 전역 상수 정의
///
/// API 기본 URL 등 환경별로 달라질 수 있는 설정값을 관리한다.
/// 빌드 시 --dart-define=API_BASE_URL=... 으로 오버라이드 가능.
class AppConstants {
  /// 앱 이름 (타이틀바 등에 사용)
  static const String appName = 'TaskManager';

  /// 백엔드 API 기본 URL
  ///
  /// 빌드 환경변수 `API_BASE_URL`로 주입.
  /// 미지정 시 로컬 개발서버(`localhost:8000`)를 기본값으로 사용.
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8000/api/v1',
  );

  /// 기본 회사 코드
  ///
  /// 빌드 환경변수 `DEFAULT_COMPANY_CODE`로 주입.
  /// company_code_screen을 스킵할 때 자동 사용.
  static const String defaultCompanyCode = String.fromEnvironment(
    'DEFAULT_COMPANY_CODE',
    defaultValue: '',
  );

  /// 키오스크 고정 매장 ID
  ///
  /// 빌드 환경변수 `KIOSK_STORE_ID`로 주입.
  /// 매장별 패드에 고정 설정하여 사용.
  static const String kioskStoreId = String.fromEnvironment(
    'KIOSK_STORE_ID',
    defaultValue: '',
  );

  /// 키오스크 고정 매장 이름
  ///
  /// 빌드 환경변수 `KIOSK_STORE_NAME`로 주입.
  static const String kioskStoreName = String.fromEnvironment(
    'KIOSK_STORE_NAME',
    defaultValue: '',
  );
}
