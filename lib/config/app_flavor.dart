/// 빌드 flavor 식별자.
///
/// `--dart-define=APP_FLAVOR=DEV` 또는 `STAGING` 으로 주입.
/// prod 빌드는 빈 문자열로 두어 badge 표시 안 함.
const String kAppFlavor =
    String.fromEnvironment('APP_FLAVOR', defaultValue: '');

bool get kHasFlavorBadge => kAppFlavor.isNotEmpty;
