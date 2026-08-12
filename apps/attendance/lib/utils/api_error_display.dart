/// API 에러 **표시기 단일 출처** (HTMA).
///
/// 파서는 `htm_core` 의 `parseApiError` 하나다. 이 파일은 그 결과를 **화면 문구**로
/// 바꾸는 층이고, 문구는 arb(l10n)에서 온다 — 두 앱 모두 es 를 유지 중이므로
/// 새 문구를 하드코딩하면 스페인어 사용자가 화면마다 언어 혼재를 보게 된다.
/// (스케줄 문구 18개가 `schedule_codes.dart` 에 영어로 하드코딩돼 있는 건 선행 예외다.
///  옮길지는 별도 판단 — 여기서는 새로 만드는 것만 arb 로 간다.)
///
/// 표시 규칙 (계약안 §4):
/// - `code_source: "status"` → **서버 문장을 그대로 띄운다.** 코드→문구 매핑을 시도하면
///   `BAD_REQUEST` 666종이 "Bad request." 하나로 뭉개져 지금보다 정보가 줄어든다.
/// - `code_source: "domain"` → 코드로 문구를 구성해도 된다. 단 **모르는 코드는
///   문구를 지어내지 않는다** — 서버 문장이 있으면 그것, 없으면 fallback + 코드 노출.
/// - transport(네트워크/타임아웃) → 서버 문장이 없으므로 arb.
/// - 500 계열 → 서버가 뭘 보냈든 arb 일반 문구. 사용자에게 스택/내부 문장을 보이지 않는다.
///
/// 코드와 trace_id 는 **본문이 아니라 하단 회색 한 줄**로 남긴다. HTMA 는 키오스크라
/// 사용자가 화면을 사진 찍어 보내는 것이 사실상 유일한 신고 경로다.
library;

import 'package:htm_core/htm_core.dart';

import '../l10n/app_localizations.dart';

/// [ApiError] → 사용자에게 보여줄 한 문장.
///
/// [fallback] 은 호출부의 맥락 문장("Couldn't save the schedule.")이다.
/// 서버가 아무 문장도 안 줬을 때만 쓰인다.
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

  // 서버가 터진 경우 — 내부 문장(예: NameError 메시지)을 사용자에게 흘리지 않는다.
  if (err.isServerFault) return t.errServerFault;

  if (err.code == kApiValidationError && !err.hasMessage) return t.errValidation;

  if (err.hasMessage) return err.message;

  // code 만 있고 message 가 없는 응답(서버에 59곳). 문구를 지어내지 않고 맥락 문장을
  // 쓰되, 코드는 [apiErrorReference] 로 화면에 남아 무엇이 걸렸는지 추적할 수 있다.
  return fallback.isNotEmpty ? fallback : t.errUnexpected;
}

/// 예외를 바로 문구로. 화면에서 가장 많이 쓰는 형태.
String apiErrorTextOf(AppL10n t, Object error, {required String fallback}) =>
    apiErrorText(t, parseApiError(error), fallback: fallback);

/// 화면 하단 회색 한 줄 (`INTERNAL_ERROR · 01J9F3K2QW`). 보여줄 게 없으면 null.
///
/// **노출 조건 = 500 + 모르는 코드.** 콘솔 `errorDisplay.ts` 의 `needsReference` 와
/// 같은 규칙이다(3-repo 표시 규칙 일치).
///
/// 예전에는 `traceId != null` 이면 무조건 참조를 돌려줬다. 서버가 봉투를 내리기
/// 시작하면 **모든** 응답에 trace_id 가 실리므로, 키오스크의 평범한 400
/// ("Break end must be after break start.") 에도 `BAD_REQUEST · SZWN…` 이 따라붙었다.
/// 손님 앞 화면에 매번 코드가 뜨면 정작 500 의 신고 단서가 소음에 묻힌다.
///
/// 콘솔은 `DOMAIN_COPY` 에 문구가 있는 코드를 "아는 코드"로 본다. 앱은 그런 표가
/// 없고 **서버 `message` 를 그대로 띄우는 것이 정본 규칙**이므로, 여기서 "아는
/// 코드"는 곧 "보여줄 문장이 있는 코드"다. 문장이 없으면 사용자는 fallback 한 줄만
/// 보게 되니 무엇이 걸렸는지 알 수 있게 코드를 남긴다.
String? apiErrorReference(ApiError err) {
  if (err.isTransport) return null;
  // 서버가 터졌다 — 사진 신고가 유일한 경로라 코드·trace_id 는 반드시 남는다.
  if (err.isServerFault) return err.reference;
  // status 를 못 읽은 병리적 응답. 콘솔 ALWAYS_SHOW_REFERENCE 와 같은 항목.
  if (err.code == kApiHttpError) return err.reference;
  // 문구가 없다 = 앱도 서버도 설명을 못 준 코드.
  if (!err.hasMessage) return err.reference;
  return null;
}

/// 시그니처 유지용 레거시 진입점 — 내부만 새 파서로 교체했다.
///
/// 호출처가 attendance/staff 양쪽에 흩어져 있어 일괄 변경하지 않는다.
/// `BuildContext` 가 없어 l10n 을 못 쓰므로, **새 화면은 [apiErrorTextOf] 를 써라.**
///
/// 예전 구현은 `detail` 이 String 일 때만 읽었다. 이제:
/// - 봉투(`error.message`) → dict `detail.message` → String `detail` 순으로 읽는다
///   (구조화 detail 이 와도 사유를 보여줄 수 있게 된 것이 이 교체의 실익이다)
/// - 네트워크 오류는 예전처럼 [fallback] (여기선 l10n 을 못 써서 영어 하드코딩을 피한다)
/// - 봉투 없는 5xx 는 [fallback] — 구버전 서버의 `text/plain "Internal Server Error"`
///   일곱 글자를 사용자에게 그대로 보여줄 이유가 없다
String extractApiError(Object e, String fallback) {
  final err = parseApiError(e);
  if (err.isTransport) return fallback;

  final base = (!err.fromEnvelope && err.isServerFault)
      ? fallback
      : (err.hasMessage ? err.message : fallback);

  final ref = apiErrorReference(err);
  return ref == null ? base : '$base\n\n$ref';
}

/// manage 세션이 끝났는가 — 끝났으면 화면이 PIN 화면으로 되돌아간다.
///
/// ⚠️ **아직 문자열 매칭이다.** 서버 `app/api/deps.py` 의 manage 세션 검증 5개 분기가
/// 아직 문자열 detail 이라 대체할 코드가 없다. 마이그레이션 4단계에서 서버가
/// 도메인 코드를 부여하면 [ApiError.code] 비교로 바꾸고 문자열 분기를 지운다.
/// 코드를 여기서 **지어내지 않는다** — 서버에 없는 코드를 앱이 먼저 정하면 3-repo
/// 계약이 앱 쪽 추측으로 시작된다.
///
/// 지금 이 판정은 **실제로 오작동 중**이다: 5개 문구 중 3개에 'session'/'expired' 가
/// 없어서(매장 변경·권한 상실 등) 매니저가 manage 모드에 갇힌다. 그래서 401/403 을
/// 함께 본다 — 문자열이 안 맞아도 세션 검증 실패면 빠져나올 수 있게 하는 임시 보강이다.
///
/// TODO(error-envelope): server deps.py 코드 부여 후 코드 비교로 교체 + 문자열 제거.
// ignore: 문자열 매칭 금지 규칙의 유일한 예외 — api_error_guard_test.dart 의 허용 목록 참조
bool isManageSessionEnded(Object error) {
  final err = parseApiError(error);
  if (err.isTransport) return false;
  // 401 = 세션 없음/불일치/매장 변경, 403 = 매니저 권한 상실. 둘 다 manage 모드 이탈.
  if (err.isUnauthorized || err.isForbidden) return true;
  final message = err.message.toLowerCase();
  return message.contains('session') || message.contains('expired');
}
