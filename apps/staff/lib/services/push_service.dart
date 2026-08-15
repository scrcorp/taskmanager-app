/// 웹 푸시 서비스 — 브라우저 구독과 서버 등록 상태를 맞춘다.
///
/// 설계의 핵심은 **의도와 능력의 분리**다:
///   - 의도(intent)  : "이 사람은 푸시를 받고 싶어한다". 서버가 보관하며 기기가
///                     바뀌어도 유지된다. (v1 은 로컬 플래그로 대체 — 서버 선호값
///                     연동은 alert 채널 작업에서 붙인다)
///   - 능력(capability): 브라우저 권한 + 살아있는 구독. **앱이 열린 그 순간에만**
///                     알 수 있다.
///
/// 둘을 한 값으로 합치면 사용자가 브라우저에서 차단했을 때 의도까지 지워져,
/// 나중에 다시 허용해도 자동 복구가 안 된다.
///
/// 서버는 구독이 끊긴 걸 통보받지 못하므로 [reconcile] 이 주 정보원이다.
library;

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_client.dart';
import 'push_helper_stub.dart'
    if (dart.library.html) 'push_helper_web.dart' as helper;

/// "받고 싶다" 는 사용자 의도를 기기에 기억해 둔다. 권한이 끊겼다 돌아왔을 때
/// 사용자가 다시 설정에 들어오지 않아도 재구독할 수 있게 하는 근거값.
const String kPushIntentKey = 'HTM_PUSH_INTENT';

final pushServiceProvider = Provider<PushService>((ref) {
  return PushService(ref.read(dioProvider));
});

/// 테스트 발송 결과 — 서버가 실제로 몇 건을 중계망에 넘겼는지.
///
/// [sent] 는 "중계 서버가 받아줬다" 까지다. 폰 화면에 떴는지는 알 수 없다
/// (OS 알림 설정이 꺼져 있으면 sent=1 이어도 안 보인다).
class PushTestResult {
  const PushTestResult({
    required this.attempted,
    required this.sent,
    required this.failed,
  });

  /// 이 사용자에게 등록된 기기 수 — 0 이면 구독 자체가 없다는 뜻이다.
  final int attempted;
  final int sent;
  final int failed;

  bool get hasDevice => attempted > 0;
  bool get delivered => sent > 0;
}

/// 화면이 보고 판단할 푸시 상태.
enum PushState {
  /// 이 브라우저/플랫폼이 웹 푸시를 지원하지 않는다 — 항목 자체를 숨긴다.
  unsupported,

  /// 아직 권한을 물어본 적 없다 — "켜기" 를 유도할 수 있다.
  prompt,

  /// 켜져 있고 구독도 살아있다.
  enabled,

  /// 권한은 있으나 사용자가 꺼 둔 상태.
  disabled,

  /// 브라우저/OS 에서 차단됨. **팝업을 다시 띄울 수 없다** — 글로 안내만 가능.
  blocked,
}

class PushService {
  final Dio _dio;

  PushService(this._dio);

  bool get isSupported => helper.isSupported();

  /// 사용자가 마지막으로 표명한 의도. 미설정이면 false.
  Future<bool> readIntent() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(kPushIntentKey) ?? false;
  }

  Future<void> _writeIntent(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kPushIntentKey, value);
  }

  /// 서버가 내려주는 VAPID 공개키. 빌드에 박지 않는 이유는 서버 push.py 주석 참조.
  Future<String?> _fetchVapidKey() async {
    final res = await _dio.get('/app/my/push/config');
    final data = res.data as Map;
    if (data['enabled'] != true) return null;
    final key = data['vapid_public_key'] as String?;
    return (key == null || key.isEmpty) ? null : key;
  }

  /// 앱 시작 시 브라우저 실제 상태와 서버 등록을 맞춘다.
  ///
  /// | 브라우저 상태        | 처리                                   |
  /// |---------------------|----------------------------------------|
  /// | granted + 구독 있음  | 서버에 upsert (last_seen 갱신)          |
  /// | granted + 구독 없음  | 의도가 ON 이면 조용히 재구독             |
  /// | denied              | 서버에서 이 기기 구독 삭제 + blocked 표시 |
  /// | default             | 아무것도 하지 않는다 (권한은 제스처 필요) |
  Future<PushState> reconcile() async {
    if (!helper.isSupported()) return PushState.unsupported;

    final permission = helper.permission();
    if (permission == 'denied') {
      // 브라우저가 막았으므로 서버에 남은 구독은 죽은 값이다. 정리한다.
      // 의도는 지우지 않는다 — 사용자가 다시 허용하면 자동 복구되어야 하므로.
      await _dropServerSubscription();
      return PushState.blocked;
    }
    if (permission != 'granted') return PushState.prompt;

    final existing = await helper.getSubscription();
    if (existing.isNotEmpty) {
      await _postSubscription(existing);
      return await readIntent() ? PushState.enabled : PushState.disabled;
    }

    // 권한은 있는데 구독이 사라진 상태 — 홈 화면 아이콘 삭제/기기 교체 등.
    // 사용자가 원했던 상태라면 다시 만들어 준다.
    if (await readIntent()) {
      final ok = await enable();
      return ok ? PushState.enabled : PushState.disabled;
    }
    return PushState.disabled;
  }

  /// 푸시 켜기 — 필요하면 권한 요청까지 한다.
  ///
  /// **반드시 사용자 탭 제스처 안에서 호출해야 한다.** 브라우저는 제스처 밖의
  /// 권한 요청을 조용히 무시한다.
  ///
  /// Returns: 구독까지 성공했으면 true.
  Future<bool> enable() async {
    if (!helper.isSupported()) return false;

    if (helper.permission() != 'granted') {
      final result = await helper.requestPermission();
      if (result != 'granted') return false;
    }

    final vapidKey = await _fetchVapidKey();
    if (vapidKey == null) return false;

    final subscription = await helper.subscribe(vapidKey);
    if (subscription.isEmpty || subscription.startsWith('ERROR:')) return false;

    // 서버 등록까지 성공해야 켜진 것이다. 여기서 실패했는데 true 를 주면
    // 토글만 켜지고 알림은 안 오는 상태로 굳는다.
    if (!await _postSubscription(subscription)) return false;
    await _writeIntent(true);
    return true;
  }

  /// 푸시 끄기 — 브라우저 구독을 해지하고 서버에서도 지운다.
  ///
  /// 권한 자체를 되돌리는 건 불가능하므로(그런 API 가 없다) 구독만 정리한다.
  Future<void> disable() async {
    await _writeIntent(false);
    final endpoint = await helper.unsubscribe();
    if (endpoint.isNotEmpty) {
      await _deleteServerSubscription(endpoint);
    } else {
      await _dropServerSubscription();
    }
  }

  /// 진단용 — 본인에게 테스트 푸시를 쏜다. prod 에는 이 엔드포인트가 없다.
  ///
  /// 응답의 숫자를 그대로 돌려준다. 호출이 성공했다는 것과 알림이 나갔다는 것은
  /// 다르다 — 등록된 기기가 없으면 200 에 sent=0 이 온다.
  Future<PushTestResult> sendTest() async {
    final res = await _dio.post('/app/my/push/test', data: {
      'title': 'HTM',
      'body': 'Push notifications are working.',
    });
    final data = Map<String, dynamic>.from(res.data as Map);
    return PushTestResult(
      attempted: (data['attempted'] as num?)?.toInt() ?? 0,
      sent: (data['sent'] as num?)?.toInt() ?? 0,
      failed: (data['failed'] as num?)?.toInt() ?? 0,
    );
  }

  /// 브리지가 준 구독 JSON 을 그대로 서버에 올린다.
  ///
  /// Returns: 서버에 등록됐으면 true.
  ///
  /// 실패를 삼키면 안 된다 — 브라우저 구독은 살아있는데 서버엔 없는 상태가 되어
  /// 토글은 켜진 것처럼 보이지만 알림은 영영 오지 않는다. 호출 측이 결과를 보고
  /// 사용자에게 알릴지 판단한다.
  Future<bool> _postSubscription(String subscriptionJson) async {
    try {
      final body = jsonDecode(subscriptionJson) as Map<String, dynamic>;
      await _dio.post('/app/my/push/subscribe', data: body);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _deleteServerSubscription(String endpoint) async {
    try {
      await _dio.post('/app/my/push/unsubscribe', data: {'endpoint': endpoint});
    } catch (_) {
      // 위와 같은 이유로 삼킨다.
    }
  }

  /// endpoint 를 모르는 상태(차단 등)에서의 정리 — 브라우저가 알려줄 수 있으면 쓴다.
  Future<void> _dropServerSubscription() async {
    final existing = await helper.getSubscription();
    if (existing.isEmpty) return;
    try {
      final endpoint = (jsonDecode(existing) as Map)['endpoint'] as String?;
      if (endpoint != null) await _deleteServerSubscription(endpoint);
    } catch (_) {
      // 무시 — 죽은 구독은 발송 시 404/410 으로도 정리된다.
    }
  }
}
