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

self.addEventListener('notificationclick', function (event) {
  event.notification.close();
  var target = (event.notification.data && event.notification.data.url) || '/';

  // 이미 열려 있는 탭이 있으면 그걸 포커스한다 — 탭이 계속 늘어나지 않게.
  event.waitUntil(
    self.clients.matchAll({ type: 'window', includeUncontrolled: true }).then(function (list) {
      for (var i = 0; i < list.length; i++) {
        var client = list[i];
        if ('focus' in client) {
          if ('navigate' in client && target !== '/') client.navigate(target);
          return client.focus();
        }
      }
      if (self.clients.openWindow) return self.clients.openWindow(target);
    })
  );
});
