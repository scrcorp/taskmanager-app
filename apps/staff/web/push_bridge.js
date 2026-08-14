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

  function getRegistration() {
    return navigator.serviceWorker.register(SW_PATH, { scope: SW_SCOPE });
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
})();
