/*
 * 웹 푸시 브리지 — Dart(push_helper_web.dart)가 호출하는 얇은 JS 층.
 *
 * Push API 는 Promise·Uint8Array·ArrayBuffer 를 오가는 브라우저 전용 API 라
 * Dart 에서 직접 다루면 지저분해진다. 여기서 평범한 JSON 으로 정규화해 넘긴다.
 *
 * 서비스워커는 /push/ 스코프에 등록한다 — 이유는 push/sw.js 주석 참조.
 */
(function () {
  var SW_PATH = 'push/sw.js';
  var SW_SCOPE = 'push/';
  // 워커 활성화 대기 상한. 넘기면 그대로 진행해 subscribe 가 판단하게 둔다.
  var SW_ACTIVATION_TIMEOUT_MS = 10000;

  function supported() {
    return (
      'serviceWorker' in navigator &&
      'PushManager' in window &&
      typeof Notification !== 'undefined'
    );
  }

  /** VAPID 공개키(base64url 문자열) → subscribe() 가 요구하는 Uint8Array. */
  function urlBase64ToUint8Array(base64url) {
    var padding = '='.repeat((4 - (base64url.length % 4)) % 4);
    var base64 = (base64url + padding).replace(/-/g, '+').replace(/_/g, '/');
    var raw = window.atob(base64);
    var output = new Uint8Array(raw.length);
    for (var i = 0; i < raw.length; ++i) output[i] = raw.charCodeAt(i);
    return output;
  }

  /** ArrayBuffer → base64url (서버로 보낼 키 형식). */
  function bufferToBase64Url(buffer) {
    var bytes = new Uint8Array(buffer);
    var binary = '';
    for (var i = 0; i < bytes.length; i++) binary += String.fromCharCode(bytes[i]);
    return window
      .btoa(binary)
      .replace(/\+/g, '-')
      .replace(/\//g, '_')
      .replace(/=+$/, '');
  }

  /** PushSubscription → 서버가 받는 JSON 문자열. 구독이 없으면 빈 문자열. */
  function serialize(subscription) {
    if (!subscription) return '';
    return JSON.stringify({
      endpoint: subscription.endpoint,
      keys: {
        p256dh: bufferToBase64Url(subscription.getKey('p256dh')),
        auth: bufferToBase64Url(subscription.getKey('auth')),
      },
      user_agent: navigator.userAgent,
    });
  }

  /**
   * 워커가 activated 될 때까지 기다린다.
   *
   * register() 는 등록 객체가 생기는 즉시 resolve 한다 — 이때 워커는 아직
   * 'installing' 이라 active 가 없다. 그 상태로 pushManager.subscribe() 를 부르면
   * 브라우저가 거절한다("no active Service Worker"). 처음 켤 때만 실패하고
   * 껐다 켜면 되는 이유가 이것이다(두 번째엔 이미 활성화돼 있다).
   *
   * navigator.serviceWorker.ready 를 쓰면 안 된다 — 그건 **현재 페이지 URL 을
   * 관장하는** 등록을 준다. 우리 SW 는 '/push/' 스코프인데 페이지는 '/' 라서
   * Flutter 의 루트 SW 가 잡힌다. 반드시 이 등록 객체의 워커를 직접 봐야 한다.
   */
  function waitUntilActive(reg) {
    if (reg.active) return Promise.resolve(reg);
    var worker = reg.installing || reg.waiting;
    if (!worker) return Promise.resolve(reg);

    return new Promise(function (resolve) {
      // 상태 전이가 오지 않는 예외 상황에서 영원히 매달리지 않도록 상한을 둔다.
      // 시간이 지나면 등록 객체를 그대로 넘겨 subscribe 가 판단하게 한다.
      var done = false;
      function finish() {
        if (done) return;
        done = true;
        resolve(reg);
      }
      var timer = setTimeout(finish, SW_ACTIVATION_TIMEOUT_MS);
      worker.addEventListener('statechange', function () {
        if (worker.state === 'activated' || worker.state === 'redundant') {
          clearTimeout(timer);
          finish();
        }
      });
    });
  }

  function getRegistration() {
    return navigator.serviceWorker
      .register(SW_PATH, { scope: SW_SCOPE })
      .then(waitUntilActive);
  }

  window.htmPush = {
    /** 이 브라우저가 웹 푸시를 지원하는가. */
    isSupported: function () {
      return supported();
    },

    /**
     * 현재 권한 상태: 'default' | 'granted' | 'denied' | 'unsupported'.
     * 'denied' 는 되돌릴 수 없다 — 팝업을 다시 띄울 방법이 없고 OS/브라우저
     * 설정으로 보내는 API 도 없다. 그래서 글로 안내하는 수밖에 없다.
     */
    permission: function () {
      if (!supported()) return 'unsupported';
      return Notification.permission;
    },

    /** 권한 요청. 반드시 사용자 탭 제스처 안에서 호출해야 브라우저가 받아준다. */
    requestPermission: function () {
      if (!supported()) return Promise.resolve('unsupported');
      return Notification.requestPermission().catch(function () {
        return 'denied';
      });
    },

    /**
     * 지금 살아있는 구독을 JSON 으로 반환(없으면 빈 문자열).
     * 앱 시작 시 서버 상태와 대조(reconcile)하는 데 쓴다 — 서버는 구독이
     * 끊긴 걸 통보받지 못하므로 이게 유일한 주 경로다.
     */
    getSubscription: function () {
      if (!supported()) return Promise.resolve('');
      return getRegistration()
        .then(function (reg) {
          return reg.pushManager.getSubscription();
        })
        .then(serialize)
        .catch(function () {
          return '';
        });
    },

    /**
     * 구독 생성(이미 있으면 그대로 반환). 성공 시 구독 JSON, 실패 시 'ERROR:...'.
     * 권한이 없으면 여기서 시도하지 않는다 — 호출 측이 먼저 권한을 받아야 한다.
     */
    subscribe: function (vapidPublicKey) {
      if (!supported()) return Promise.resolve('ERROR:unsupported');
      if (Notification.permission !== 'granted') {
        return Promise.resolve('ERROR:permission-' + Notification.permission);
      }
      if (!vapidPublicKey) return Promise.resolve('ERROR:no-vapid-key');

      return getRegistration()
        .then(function (reg) {
          return reg.pushManager.getSubscription().then(function (existing) {
            if (existing) return existing;
            return reg.pushManager.subscribe({
              userVisibleOnly: true, // 표준 요구사항 — 조용한 푸시는 허용되지 않는다
              applicationServerKey: urlBase64ToUint8Array(vapidPublicKey),
            });
          });
        })
        .then(serialize)
        .catch(function (e) {
          return 'ERROR:' + (e && e.message ? e.message : e);
        });
    },

    /** 브라우저 쪽 구독 해지. 해지 전 endpoint 를 반환(서버에서도 지워야 하므로). */
    unsubscribe: function () {
      if (!supported()) return Promise.resolve('');
      return getRegistration()
        .then(function (reg) {
          return reg.pushManager.getSubscription();
        })
        .then(function (sub) {
          if (!sub) return '';
          var endpoint = sub.endpoint;
          return sub.unsubscribe().then(function () {
            return endpoint;
          });
        })
        .catch(function () {
          return '';
        });
    },
  };

  // ── 알림 클릭 → 화면 이동 ────────────────────────────────
  // 서비스워커는 스코프가 '/push/' 라 루트 페이지를 제어하지 않는다. 그래서
  // client.navigate() 를 쓸 수 없고(제어 중일 때만 허용), 대신 워커가 보낸
  // 메시지를 여기서 받아 페이지가 직접 이동한다.
  //
  // 지금은 전체 로드다. Flutter 라우터에 물리면 새로고침 없이 전환할 수 있는데,
  // 그건 라우터 접근이 필요해 별도 작업으로 둔다 — 우선 이동이 되게 한다.
  if ('serviceWorker' in navigator) {
    navigator.serviceWorker.addEventListener('message', function (event) {
      var data = event.data;
      if (!data || data.type !== 'htm-push-navigate') return;

      var url = data.url;
      // 같은 오리진의 경로만 받는다. '//host' 는 프로토콜 상대 URL 이라 외부로 나간다.
      if (typeof url !== 'string' || url.charAt(0) !== '/' || url.charAt(1) === '/') return;

      // 앱이 path 전략이므로 워커가 '/schedule' 형태로 준다
      // (라우팅 규약은 sw.js 의 toAppUrl 한 곳만 안다).
      // 이미 그 화면이면 아무것도 하지 않는다 — 불필요한 새로고침 방지.
      if (window.location.pathname === url) return;

      window.location.href = url;
    });

    // addEventListener 로 받을 때는 메시지 전달이 잠겨 있을 수 있다(onmessage 대입
    // 이나 이 호출, 또는 load 완료로 풀린다). 명시적으로 열어 둔다 — 알림 클릭은
    // load 한참 뒤라 대개 괜찮지만, 조용히 안 오는 실패는 진단이 어렵다.
    if (typeof navigator.serviceWorker.startMessages === 'function') {
      navigator.serviceWorker.startMessages();
    }
  }
})();
