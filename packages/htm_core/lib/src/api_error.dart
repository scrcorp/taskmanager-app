/// API 에러 **파서 단일 출처** — attendance(HTMA)/staff 양쪽이 공유한다.
///
/// 배경: 에러 처리 일원화 트랙(`docs/99_inbox/2026-08-11 에러 처리 일원화 - 설계.md`).
/// 서버가 전역 예외 핸들러에서 **봉투(envelope)** 를 내려주기 시작한다.
///
/// ```jsonc
/// {
///   "detail": <원형 그대로 — 문자열이면 문자열, dict 였으면 그 dict 원형>,
///   "error": {                       // ← 정본(canonical)
///     "code": "UPPER_SNAKE",
///     "code_source": "domain" | "status",
///     "message": "사용자에게 보여줄 원인 한 문장",
///     "hint": "다음 행동" | null,
///     "params": { ... },
///     "trace_id": "01J9F3K2QW"
///   }
/// }
/// ```
///
/// **`error` 가 정본, `detail` 은 읽기 전용 레거시 미러다.** 서버는 항상 `error` 를 먼저
/// 만들고 `detail` 을 그로부터 파생시킨다. 그래서 이 파서도 `error` 를 먼저 읽고,
/// 없을 때만 `detail` 로 내려간다(구버전 서버 호환).
///
/// ## 왜 `detail` 을 계속 읽어야 하나
/// 서버는 `detail` 을 **바이트 동일하게** 유지하기로 했다(계약안 X1). 이유는 구버전 HTMA
/// 파서가 `detail` 이 String 일 때만 읽기 때문인데, 그걸 dict 로 바꾸는 순간 현장에 깔린
/// 사이드로드 APK 666곳의 에러 사유가 전부 호출부 fallback 문장으로 퇴화하고
/// **조기 clock-in / 겹침 확인 모달 2건은 기능이 정지**한다. 되돌릴 수단이 서버 롤백뿐이다.
/// 따라서 신버전 앱도 `detail` 폴백을 **영구적으로** 갖고 있어야 한다 —
/// 서버가 `detail` 을 지우는 날은 3-repo 동시 배포 + `min_version` 컷과 함께 온다.
///
/// ## dio 의존성이 없는 이유
/// `htm_core` 는 네트워킹 패키지를 갖고 있지 않고, 이 파서 하나 때문에 dio 를 끌어오면
/// 공유 패키지가 앱의 HTTP 스택에 묶인다. 그래서 `DioException` 을 타입으로 받지 않고
/// `(e as dynamic).response` / `.type` 을 **덕 타이핑**으로 읽는다. 기존
/// `extractApiError` 도 같은 방식이었고 3년째 문제없이 동작했다.
library;

/// 코드의 출처. **표시기가 문구를 만들지, 서버 문장을 그대로 쓸지를 이 값으로 가른다.**
///
/// - [domain] — 서버가 의미를 부여한 코드. 표시기가 코드→문구를 구성해도 된다.
/// - [status] — HTTP status 에서 유도한 일반 코드(`BAD_REQUEST` 666종이 여기 온다).
///   **코드→문구 매핑을 시도하면 안 된다.** `BAD_REQUEST` 하나에 "Bad request." 를
///   매핑하는 순간 지금보다 정보가 줄어든다. 반드시 [ApiError.message] 를 그대로 띄운다.
/// - [transport] — 서버까지 못 갔다(타임아웃/연결 실패/취소). **클라이언트가 붙인 코드**이며
///   서버 문장이 없으므로 문구는 앱 l10n(arb)에서 온다.
enum ApiErrorSource { domain, status, transport }

/// 검증 항목 하나 — `{"code": ..., "params": {...}}`.
///
/// 스케줄의 `ScheduleIssue` 와 같은 모양이다. 그쪽은 스케줄 전용 문구까지 들고 있어서
/// 합치지 않았다(도메인 문구를 공유 패키지로 올리면 앱별 맥락이 섞인다).
class ApiIssue {
  final String code;
  final Map<String, dynamic> params;

  const ApiIssue(this.code, [this.params = const {}]);

  static ApiIssue? tryParse(dynamic raw) {
    if (raw is! Map) return null;
    final code = raw['code']?.toString();
    if (code == null || code.isEmpty) return null;
    final p = raw['params'];
    return ApiIssue(code, p is Map ? Map<String, dynamic>.from(p) : const {});
  }
}

// ── status 기반 일반 코드 (서버 고정표의 클라 측 짝) ──────────────────────
//
// 봉투가 없는 구버전 서버 응답을 읽을 때만 쓴다. 봉투가 오면 서버가 준 code 를 그대로 쓴다.
// 서버 표는 예외 클래스 기준이라 `DuplicateError → DUPLICATE` 처럼 status 만으로는
// 복원할 수 없는 항목이 있다. 클라는 status 로만 판단하므로 409 는 CONFLICT 로 둔다 —
// **이 값으로 분기하지 마라.** 분기는 봉투의 domain 코드로만 한다.

const String kApiBadRequest = 'BAD_REQUEST';
const String kApiUnauthorized = 'UNAUTHORIZED';
const String kApiForbidden = 'FORBIDDEN';
const String kApiNotFound = 'NOT_FOUND';
const String kApiConflict = 'CONFLICT';
const String kApiGone = 'GONE';
const String kApiPayloadTooLarge = 'PAYLOAD_TOO_LARGE';
const String kApiValidationError = 'VALIDATION_ERROR';
const String kApiTooManyRequests = 'TOO_MANY_REQUESTS';
const String kApiServiceUnavailable = 'SERVICE_UNAVAILABLE';
const String kApiInternalError = 'INTERNAL_ERROR';

/// status 를 모를 때(응답은 왔는데 statusCode 가 없는 병리적 경우).
const String kApiHttpError = 'HTTP_ERROR';

// ── transport 코드 (클라이언트 전용. 서버에는 짝이 없다) ──────────────────
//
// 지금은 각 화면이 `e.type == DioExceptionType.connectionError` 를 각자 해석한다.
// 여기로 모아야 "네트워크 문제"와 "서버가 거절함"을 표시기가 구분할 수 있다.

const String kApiNetworkTimeout = 'NETWORK_TIMEOUT';
const String kApiNetworkUnreachable = 'NETWORK_UNREACHABLE';
const String kApiNetworkInsecure = 'NETWORK_INSECURE';
const String kApiRequestCancelled = 'REQUEST_CANCELLED';
const String kApiNetworkError = 'NETWORK_ERROR';

/// 3-repo 목록 일치 검사(G3)의 앱 측 입력.
///
/// status 계열은 서버 고정표와 같아야 하고, transport 계열은 클라 전용이라 제외한다.
const Set<String> kApiStatusCodes = {
  kApiBadRequest,
  kApiUnauthorized,
  kApiForbidden,
  kApiNotFound,
  kApiConflict,
  kApiGone,
  kApiPayloadTooLarge,
  kApiValidationError,
  kApiTooManyRequests,
  kApiServiceUnavailable,
  kApiInternalError,
  kApiHttpError,
};

const Set<String> kApiTransportCodes = {
  kApiNetworkTimeout,
  kApiNetworkUnreachable,
  kApiNetworkInsecure,
  kApiRequestCancelled,
  kApiNetworkError,
};

/// 봉투 `error` 안에서 [ApiError.params] 로 내리지 않는 키.
///
/// E1-b 화이트리스트 — `errors`/`warnings`/`retry`/`hint` 는 **최상위 유지**다.
/// (스케줄 409 의 `warnings`/`retry` 가 `params` 밑으로 들어가면 겹침 확인 모달이 죽는다.)
const Set<String> _envelopeReservedKeys = {
  'code',
  'code_source',
  'message',
  'hint',
  'params',
  'errors',
  'warnings',
  'retry',
  'trace_id',
};

/// 파싱된 에러 — 화면이 보는 유일한 형태.
class ApiError {
  /// 항상 값이 있다. 봉투가 없으면 status/transport 에서 유도한 일반 코드.
  final String code;

  final ApiErrorSource source;

  /// 서버가 준 사람이 읽을 문장. **없으면 빈 문자열이다.**
  ///
  /// null 대신 빈 문자열인 이유: 호출부가 `?? fallback` 을 빼먹어 화면에 "null" 이
  /// 찍히는 사고를 구조적으로 없애기 위함. 비었는지는 [hasMessage] 로 본다.
  final String message;

  /// 다음 행동 안내. 서버가 줬을 때만.
  final String? hint;

  /// 부가 파라미터. 봉투면 `error.params`, 레거시 dict 면 화이트리스트 밖의 남은 키들.
  final Map<String, dynamic> params;

  /// 검증 항목들(주로 스케줄 400/409). 없으면 빈 리스트.
  final List<ApiIssue> errors;
  final List<ApiIssue> warnings;

  /// 재시도 힌트(예: `{"force": true}`). 없으면 null.
  final Map<String, dynamic>? retry;

  /// 화면↔서버 로그를 잇는 키. **`request_id` 가 아니다** — 스케줄 변경요청 FK 가
  /// 그 이름을 이미 점유하고 있어 같은 응답 안에서 의미가 충돌한다.
  final String? traceId;

  /// HTTP status. 응답 자체가 없으면(transport) null.
  final int? statusCode;

  /// 서버가 봉투(`error` 키)를 보냈는가. 진척 측정/디버깅용.
  final bool fromEnvelope;

  const ApiError({
    required this.code,
    required this.source,
    this.message = '',
    this.hint,
    this.params = const {},
    this.errors = const [],
    this.warnings = const [],
    this.retry,
    this.traceId,
    this.statusCode,
    this.fromEnvelope = false,
  });

  bool get hasMessage => message.trim().isNotEmpty;

  bool get isDomain => source == ApiErrorSource.domain;
  bool get isTransport => source == ApiErrorSource.transport;

  /// 서버까지 갔지만 서버가 터진 경우 — 표시기가 "서버 오류" 배너로 따로 다룬다.
  bool get isServerFault =>
      code == kApiInternalError ||
      code == kApiServiceUnavailable ||
      (statusCode != null && statusCode! >= 500);

  bool get isUnauthorized => statusCode == 401 || code == kApiUnauthorized;
  bool get isForbidden => statusCode == 403 || code == kApiForbidden;

  /// 화면 하단 회색 한 줄 — `INTERNAL_ERROR · 01J9F3K2QW`.
  ///
  /// HTMA 는 키오스크라 사용자가 **사진을 찍어 보내는 것이 유일한 신고 경로**다.
  /// 그래서 코드와 trace_id 는 반드시 화면에 남는다(계약안 §4).
  String get reference => traceId == null ? code : '$code · $traceId';

  @override
  String toString() =>
      'ApiError($code, ${source.name}, status=$statusCode, trace=$traceId)';
}

/// dio/기타 예외 → [ApiError].
///
/// 순서:
/// 1. 응답 body 의 `error`(봉투, 정본)
/// 2. 없으면 `detail`(레거시 미러: String / Map / List(422))
/// 3. body 가 문자열이면 그대로 문장 취급 (구버전 500 은 `text/plain` 이다)
/// 4. 응답 자체가 없으면 transport 코드
///
/// **문자열을 코드로 추론하지 않는다**(X4). 서버 문장이 바뀌면 조용히 깨지는 분기를
/// 클라이언트 안으로 되가져오는 것과 같기 때문이다.
ApiError parseApiError(Object error) {
  dynamic response;
  try {
    response = (error as dynamic).response;
  } catch (_) {
    response = null;
  }

  if (response == null) return _transportError(error);

  int? status;
  dynamic data;
  try {
    status = (response as dynamic).statusCode as int?;
  } catch (_) {
    status = null;
  }
  try {
    data = (response as dynamic).data;
  } catch (_) {
    data = null;
  }

  if (data is Map) {
    final envelope = data['error'];
    if (envelope is Map) return _fromEnvelope(envelope, status);
    return _fromLegacyDetail(data['detail'], status);
  }

  if (data is String && data.trim().isNotEmpty) {
    // 구버전 서버의 500 은 JSON 이 아니라 `text/plain "Internal Server Error"` 다.
    return ApiError(
      code: _codeForStatus(status),
      source: ApiErrorSource.status,
      message: data.trim(),
      statusCode: status,
    );
  }

  return ApiError(
    code: _codeForStatus(status),
    source: ApiErrorSource.status,
    statusCode: status,
  );
}

ApiError _fromEnvelope(Map envelope, int? status) {
  final code = envelope['code']?.toString();
  final rawSource = envelope['code_source']?.toString();
  // 서버가 code_source 를 안 보냈거나 모르는 값이면 status 로 본다 —
  // "모르면 문구를 지어내지 않는다"가 안전한 쪽이다.
  final source =
      rawSource == 'domain' ? ApiErrorSource.domain : ApiErrorSource.status;

  final params = <String, dynamic>{};
  final rawParams = envelope['params'];
  if (rawParams is Map) params.addAll(Map<String, dynamic>.from(rawParams));
  // 서버가 아직 params 로 옮기지 않은 미지 키도 잃지 않는다.
  for (final entry in envelope.entries) {
    final key = entry.key.toString();
    if (_envelopeReservedKeys.contains(key)) continue;
    params.putIfAbsent(key, () => entry.value);
  }

  return ApiError(
    code: (code == null || code.isEmpty) ? _codeForStatus(status) : code,
    source: (code == null || code.isEmpty) ? ApiErrorSource.status : source,
    message: envelope['message']?.toString() ?? '',
    hint: _nonEmpty(envelope['hint']),
    params: params,
    errors: _issues(envelope['errors']),
    warnings: _issues(envelope['warnings']),
    retry: envelope['retry'] is Map
        ? Map<String, dynamic>.from(envelope['retry'] as Map)
        : null,
    traceId: _nonEmpty(envelope['trace_id']),
    statusCode: status,
    fromEnvelope: true,
  );
}

ApiError _fromLegacyDetail(dynamic detail, int? status) {
  if (detail is String) {
    return ApiError(
      code: _codeForStatus(status),
      source: ApiErrorSource.status,
      message: detail,
      statusCode: status,
    );
  }

  if (detail is Map) {
    final code = detail['code']?.toString();
    // 화이트리스트 밖의 평탄 키(`minutes_early`, `other_store` 등)를 params 로 모은다.
    // ⚠️ 이건 **클라 모델 안에서만** 하는 정규화다. 서버가 내려주는 `detail` 자체는
    //    원형(평탄 구조)이 유지된다 — 구버전 앱이 `minutes_early` 를 못 찾으면
    //    "0m early" 같은 **틀린 정보를 맞는 것처럼** 표시한다(계약안 X3).
    final params = <String, dynamic>{};
    for (final entry in detail.entries) {
      final key = entry.key.toString();
      if (_envelopeReservedKeys.contains(key)) continue;
      params[key] = entry.value;
    }
    final rawParams = detail['params'];
    if (rawParams is Map) {
      for (final e in Map<String, dynamic>.from(rawParams).entries) {
        params.putIfAbsent(e.key, () => e.value);
      }
    }

    return ApiError(
      code: (code == null || code.isEmpty) ? _codeForStatus(status) : code,
      source: (code == null || code.isEmpty)
          ? ApiErrorSource.status
          : ApiErrorSource.domain,
      message: detail['message']?.toString() ?? '',
      hint: _nonEmpty(detail['hint']),
      params: params,
      errors: _issues(detail['errors']),
      warnings: _issues(detail['warnings']),
      retry: detail['retry'] is Map
          ? Map<String, dynamic>.from(detail['retry'] as Map)
          : null,
      statusCode: status,
    );
  }

  if (detail is List) {
    // FastAPI 422 원형: [{type, loc, msg, input}, ...]
    final fields = <Map<String, dynamic>>[];
    final lines = <String>[];
    for (final raw in detail) {
      if (raw is! Map) continue;
      final loc = raw['loc'];
      final field = loc is List
          ? loc.where((l) => l != 'body' && l != 'query').join(' > ')
          : '';
      final reason = raw['msg']?.toString() ?? raw['type']?.toString() ?? '';
      fields.add({'field': field, 'reason': raw['type']?.toString() ?? ''});
      lines.add(field.isEmpty ? reason : '$field: $reason');
    }
    return ApiError(
      code: kApiValidationError,
      source: ApiErrorSource.status,
      message: lines.join('\n'),
      params: {'fields': fields},
      statusCode: status,
    );
  }

  return ApiError(
    code: _codeForStatus(status),
    source: ApiErrorSource.status,
    statusCode: status,
  );
}

List<ApiIssue> _issues(dynamic raw) {
  if (raw is! List) return const [];
  return raw.map(ApiIssue.tryParse).whereType<ApiIssue>().toList();
}

String? _nonEmpty(dynamic raw) {
  final s = raw?.toString();
  if (s == null || s.trim().isEmpty) return null;
  return s;
}

String _codeForStatus(int? status) {
  switch (status) {
    case 400:
      return kApiBadRequest;
    case 401:
      return kApiUnauthorized;
    case 403:
      return kApiForbidden;
    case 404:
      return kApiNotFound;
    case 409:
      return kApiConflict;
    case 410:
      return kApiGone;
    case 413:
      return kApiPayloadTooLarge;
    case 422:
      return kApiValidationError;
    case 429:
      return kApiTooManyRequests;
    case 500:
      return kApiInternalError;
    case 502:
    case 503:
    case 504:
      return kApiServiceUnavailable;
  }
  if (status != null && status >= 500) return kApiInternalError;
  return kApiHttpError;
}

/// 응답이 없는 예외 — 서버까지 못 갔거나, 애초에 HTTP 예외가 아니다.
///
/// dio 를 import 하지 않으므로 `DioExceptionType` 열거값을 이름으로 읽는다.
/// (dio 가 이름을 바꾸면 `NETWORK_ERROR` 로 떨어질 뿐 깨지지는 않는다.)
///
/// ⚠️ `.name` 을 dynamic 으로 부르면 **항상 실패**한다 — enum 의 `name` 은 인스턴스
/// 멤버가 아니라 확장(`EnumName`)이고 dynamic 디스패치는 확장을 찾지 못한다.
/// 그래서 `toString()`("DioExceptionType.connectionTimeout")의 마지막 조각을 쓴다.
ApiError _transportError(Object error) {
  String? typeName;
  try {
    final type = (error as dynamic).type;
    if (type != null) {
      final s = type.toString();
      final dot = s.lastIndexOf('.');
      typeName = dot < 0 ? s : s.substring(dot + 1);
    }
  } catch (_) {
    typeName = null;
  }

  switch (typeName) {
    case 'connectionTimeout':
    case 'sendTimeout':
    case 'receiveTimeout':
      return const ApiError(
          code: kApiNetworkTimeout, source: ApiErrorSource.transport);
    case 'connectionError':
      return const ApiError(
          code: kApiNetworkUnreachable, source: ApiErrorSource.transport);
    case 'badCertificate':
      return const ApiError(
          code: kApiNetworkInsecure, source: ApiErrorSource.transport);
    case 'cancel':
      return const ApiError(
          code: kApiRequestCancelled, source: ApiErrorSource.transport);
  }

  return const ApiError(
      code: kApiNetworkError, source: ApiErrorSource.transport);
}
