import 'package:flutter_test/flutter_test.dart';
import 'package:app/utils/date_utils.dart';

void main() {
  const kst = Duration(hours: 9);
  const pdt = Duration(hours: -7);
  const ist = Duration(hours: 5, minutes: 30);

  group('tzLabel', () {
    test('웹(영어 로케일)의 긴 존 이름을 약어로 줄인다', () {
      // 브라우저가 주는 형태 — 워터마크엔 너무 길다.
      expect(tzLabel('Korea Standard Time', kst), 'KST');
      expect(tzLabel('Korean Standard Time', kst), 'KST');
      expect(tzLabel('Pacific Daylight Time', pdt), 'PDT');
      expect(tzLabel('Central European Summer Time', const Duration(hours: 2)), 'CEST');
    });

    test('네이티브가 주는 약어는 그대로 둔다', () {
      // Android/iOS 의 DateTime.timeZoneName — 이미 짧다.
      expect(tzLabel('KST', kst), 'KST');
      expect(tzLabel('PDT', pdt), 'PDT');
      expect(tzLabel('UTC', Duration.zero), 'UTC');
      expect(tzLabel('GMT+9', kst), 'GMT+9');
    });

    test('현지어 이름(비ASCII)은 GMT 오프셋으로 폴백한다', () {
      // 한국어 로케일 브라우저: "대한민국 표준시" → 약어 불가 → 짧은 오프셋으로.
      expect(tzLabel('대한민국 표준시', kst), 'GMT+9');
      expect(tzLabel('日本標準時', const Duration(hours: 9)), 'GMT+9');
      expect(tzLabel('heure normale du Pacifique', pdt), 'GMT-7');
    });

    test('30분 단위 오프셋도 표기한다', () {
      expect(tzLabel('인도 표준시', ist), 'GMT+5:30');
    });

    test('이름이 없으면 오프셋으로 폴백', () {
      expect(tzLabel('', kst), 'GMT+9');
      expect(tzLabel('', Duration.zero), 'GMT+0');
    });
  });

  group('formatDateTimeWithZone', () {
    test('연도와 짧은 존 라벨을 함께 표시한다', () {
      final out = formatDateTimeWithZone(DateTime.utc(2026, 3, 5, 9, 0));
      // 존 라벨은 실행 기기 로컬 기준이라 값 자체는 고정할 수 없지만,
      // 연도가 포함되고 긴 이름("... Standard Time")이 아니어야 한다.
      expect(out, contains('2026'));
      expect(out, isNot(contains('Standard Time')));
      expect(out, matches(RegExp(r'\d:\d{2} [AP]M')));
      // 존 라벨은 짧아야 한다(약어 또는 GMT 오프셋).
      final zone = out.split(' ').last;
      expect(zone.length, lessThanOrEqualTo(8));
    });
  });
}
