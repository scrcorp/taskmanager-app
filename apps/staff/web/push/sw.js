/*
 * 웹 푸시 전용 서비스워커.
 *
 * 왜 /push/ 하위에 따로 두는가:
 *   Flutter 릴리스 빌드는 루트 스코프('/')에 flutter_service_worker.js 를 등록한다.
 *   한 스코프에는 서비스워커가 하나뿐이라, 루트에 우리 워커를 등록하면 Flutter 것을
 *   밀어내고 오프라인 캐싱이 깨진다.
 *   푸시 구독은 "등록(registration)" 에 붙는 것이지 페이지를 제어할 필요가 없으므로,
 *   이 파일을 /push/ 아래 두어 스코프를 분리하면 둘이 공존한다.
 *
 * 페이로드는 서버(push_service.py)가 JSON 으로 보낸다:
 *   { title, body, url, tag }
 */

// 설치 즉시 활성화 — 갱신된 워커가 다음 방문을 기다리지 않게 한다.
self.addEventListener('install', function (event) {
  self.skipWaiting();
});

self.addEventListener('activate', function (event) {
  event.waitUntil(self.clients.claim());
});

self.addEventListener('push', function (event) {
  var payload = { title: 'HTM', body: '', url: '/', tag: null };

  if (event.data) {
    try {
      var parsed = event.data.json();
      payload.title = parsed.title || payload.title;
      payload.body = parsed.body || payload.body;
      payload.url = parsed.url || payload.url;
      payload.tag = parsed.tag || null;
    } catch (e) {
      // JSON 이 아니면 평문으로 취급 — 알림을 아예 안 띄우는 것보단 낫다.
      payload.body = event.data.text();
    }
  }

  var options = {
    body: payload.body,
    icon: '/icons/Icon-192.png',
    badge: '/icons/Icon-192.png',
    data: { url: payload.url },
  };
  // 같은 tag 는 기기에서 덮어쓰기된다 — 같은 종류 알림이 쌓이는 걸 막는다.
  if (payload.tag) options.tag = payload.tag;

  event.waitUntil(self.registration.showNotification(payload.title, options));
});

/**
 * 서버가 보낸 논리 경로('/schedule')를 이 앱이 해석하는 URL 로 바꾼다.
 *
 * 앱이 path 전략(usePathUrlStrategy)을 쓰므로 경로가 곧 라우트다 — 변환이 없다.
 * 라우팅 규약을 아는 곳은 여기 하나뿐이니, 규약이 바뀌면 이 함수만 고치면 된다.
 *
 * 남은 일은 검증뿐이다: 절대경로가 아니면 홈으로 보낸다. 페이로드에 외부 URL 이
 * 들어와도 다른 사이트로 튀지 않게 하는 게 목적이다.
 */
function toAppUrl(route) {
  if (typeof route !== 'string') return '/';
  if (route.charAt(0) !== '/') return '/';
  if (route.charAt(1) === '/') return '/';   // '//host' = 프로토콜 상대 URL
  return route;
}

self.addEventListener('notificationclick', function (event) {
  event.notification.close();
  var route = (event.notification.data && event.notification.data.url) || '/';
  var target = toAppUrl(route);

  // 이미 열려 있는 탭이 있으면 그걸 포커스한다 — 탭이 계속 늘어나지 않게.
  //
  // 이동은 client.navigate() 로 하면 안 된다. 그 메서드는 **이 서비스워커가 그 페이지를
  // 제어(control)할 때만** 허용되고 아니면 TypeError 로 거부된다. 우리 워커는 '/push/'
  // 스코프라 루트 페이지를 제어하지 않는다(루트는 Flutter 워커 몫). 즉 여기서
  // navigate 를 부르면 조용히 거부되어, 앱이 앞으로 오기만 하고 화면은 그대로였다.
  //
  // 대신 포커스한 탭에 메시지를 보내고 이동은 페이지가 한다(push_bridge.js 가 수신).
  // 제어 여부와 무관하게 동작하며, 나중에 라우터에 물리면 새로고침 없이 전환도 된다.
  event.waitUntil(
    self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then(function (list) {
      for (var i = 0; i < list.length; i++) {
        var client = list[i];
        if ('focus' in client) {
          return client.focus().then(function (focused) {
            var c = focused || client;
            if (c && typeof c.postMessage === 'function') {
              c.postMessage({ type: 'htm-push-navigate', url: target });
            }
            return c;
          });
        }
      }
      // 열린 탭이 없으면 새 창을 target 으로 직접 연다 — 이 경로는 원래도 정상이었다.
      if (self.clients.openWindow) return self.clients.openWindow(target);
    })
  );
});
