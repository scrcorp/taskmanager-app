/// 웹용 — 주소창에서 '#' 을 없앤다(path 전략).
///
/// 반드시 runApp 전에, 그리고 GoRouter 가 만들어지기 전에 호출해야 한다.
/// 나중에 부르면 라우터가 이미 해시 기준으로 초기 경로를 읽은 뒤다.
import 'package:flutter_web_plugins/url_strategy.dart';

void configureUrlStrategy() {
  usePathUrlStrategy();
}
