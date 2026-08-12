/// API 에러 **표시기 단일 출처** (staff app).
///
/// 파서는 `htm_core` 의 `parseApiError` 하나이고, 이 파일은 그 결과를 **화면 문구**로
/// 바꾼다. HTMA 쪽 짝은 `apps/attendance/lib/utils/api_error_display.dart` —
/// 규칙은 같고 문구만 앱별 arb 에서 온다(키오스크 vs 폼이라 맥락이 다르다).
///
/// 표시 규칙 (계약안 §4):
/// - `code_source: "status"` → **서버 문장을 그대로.** 코드→문구 매핑을 시도하면
///   `BAD_REQUEST` 수백 종이 문구 하나로 뭉개져 지금보다 정보가 줄어든다.
/// - `code_source: "domain"` → 코드로 문구 구성 가능. 단 **모르는 코드는 지어내지 않는다.**
/// - transport(네트워크/타임아웃) → 서버 문장이 없으므로 arb.
/// - 5xx → arb 일반 문구 + 하단 회색 한 줄에 코드·trace_id.
library;

import 'package:htm_core/htm_core.dart';

import '../l10n/app_localizations.dart';

/// [ApiError] → 사용자에게 보여줄 한 문장.
///
/// [fallback] 은 호출부의 맥락 문장이며 서버가 아무 문장도 안 줬을 때만 쓰인다.
String apiErrorText(AppL10n t, ApiError err, {required String fallback}) {
  if (err.isTransport) {
    switch (err.code) {
      case kApiNetworkTimeout:
        return t.errNetworkTimeout;
      case kApiNetworkUnreachable:
        return t.errNetworkUnreachable;
      case kApiNetworkInsecure:
        return t.errNetworkInsecure;
      case kApiRequestCancelled:
        return t.errRequestCancelled;
      default:
        return t.errNetworkGeneric;
    }
  }

  // 서버 내부 예외 문장(스택·변수명 등)을 사용자에게 흘리지 않는다.
  if (err.isServerFault) return t.errServerFault;

  if (err.code == kApiValidationError && !err.hasMessage) return t.errValidation;

  if (err.hasMessage) return err.message;

  return fallback.isNotEmpty ? fallback : t.errUnexpected;
}

/// 예외를 바로 문구로.
String apiErrorTextOf(AppL10n t, Object error, {required String fallback}) =>
    apiErrorText(t, parseApiError(error), fallback: fallback);

/// 화면 하단 회색 한 줄 (`INTERNAL_ERROR · 01J9F3K2QW`). 보여줄 게 없으면 null.
///
/// **노출 조건 = 500 + 모르는 코드.** 콘솔 `errorDisplay.ts` 의 `needsReference`,
/// HTMA 의 같은 이름 함수와 규칙을 맞춘다.
///
/// 예전의 `traceId != null` 무조건 노출은, 서버가 봉투를 내리기 시작하면 모든
/// 응답에 trace_id 가 실린다는 점에서 "항상 노출"과 같았다. 평범한 400 에도 코드가
/// 붙으면 정작 500 의 신고 단서가 묻힌다.
String? apiErrorReference(ApiError err) {
  if (err.isTransport) return null;
  if (err.isServerFault) return err.reference;
  if (err.code == kApiHttpError) return err.reference;
  // 보여줄 문장이 없는 코드 = 앱도 서버도 설명을 못 준 코드.
  if (!err.hasMessage) return err.reference;
  return null;
}

/// l10n 없이 쓰는 진입점 — provider/service 처럼 `BuildContext` 가 없는 자리용.
///
/// HTMA 의 같은 이름 함수와 **동작이 같다**(두 앱의 파서를 하나로 모으는 것이 이 트랙의
/// 목적이라 의도적으로 맞췄다). 새 화면 코드는 [apiErrorTextOf] 를 써라 — 이쪽은
/// 네트워크 오류를 구분해서 안내하지 못한다(영어 하드코딩을 피하려고 fallback 으로 둔다).
String extractApiError(Object e, String fallback) {
  final err = parseApiError(e);
  if (err.isTransport) return fallback;

  final base = (!err.fromEnvelope && err.isServerFault)
      ? fallback
      : (err.hasMessage ? err.message : fallback);

  final ref = apiErrorReference(err);
  return ref == null ? base : '$base\n\n$ref';
}
