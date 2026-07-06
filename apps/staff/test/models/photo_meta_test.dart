import 'package:flutter_test/flutter_test.dart';
import 'package:app/models/photo_meta.dart';

void main() {
  group('PhotoMeta.toJson (서버 payload)', () {
    test('라이브: key + capture_time(UTC ISO) + capture_source 모두 포함', () {
      final meta = PhotoMeta(
        key: 'completions/2026/06/22/a.jpg',
        captureTime: DateTime.utc(2026, 6, 22, 9, 0, 0),
        captureSource: 'live',
      );
      final json = meta.toJson();
      expect(json['key'], 'completions/2026/06/22/a.jpg');
      expect(json['capture_time'], '2026-06-22T09:00:00.000Z');
      expect(json['capture_source'], 'live');
    });

    test('갤러리(EXIF 시각 있음): capture_source=gallery', () {
      final meta = PhotoMeta(
        key: 'k.jpg',
        captureTime: DateTime.utc(2026, 6, 1, 12, 30, 0),
        captureSource: 'gallery',
      );
      expect(meta.toJson()['capture_source'], 'gallery');
      expect(meta.toJson()['capture_time'], '2026-06-01T12:30:00.000Z');
    });

    test('미상(EXIF 없음/레거시): capture_time·capture_source 키 생략 → 서버가 unknown 처리', () {
      final meta = PhotoMeta(key: 'legacy.jpg');
      final json = meta.toJson();
      expect(json.containsKey('capture_time'), false);
      expect(json.containsKey('capture_source'), false);
      expect(json['key'], 'legacy.jpg');
    });

    test('로컬 시각도 UTC 로 직렬화한다', () {
      final local = DateTime(2026, 6, 22, 9, 0, 0); // 로컬
      final meta = PhotoMeta(key: 'k', captureTime: local, captureSource: 'live');
      expect(meta.toJson()['capture_time'], endsWith('Z'));
    });
  });

  group('PhotoMeta draft 직렬화 round-trip', () {
    test('capture_time/source 보존', () {
      final meta = PhotoMeta(
        key: 'k.jpg',
        captureTime: DateTime.utc(2026, 6, 22, 9, 0, 0),
        captureSource: 'live',
      );
      final restored = PhotoMeta.fromDraftJson(meta.toDraftJson());
      expect(restored.key, 'k.jpg');
      expect(restored.captureTime, DateTime.utc(2026, 6, 22, 9, 0, 0));
      expect(restored.captureSource, 'live');
    });

    test('null 시각/출처도 draft 에 명시 저장되어 복원된다', () {
      final meta = PhotoMeta(key: 'k.jpg');
      final draft = meta.toDraftJson();
      expect(draft.containsKey('capture_time'), true);
      expect(draft['capture_time'], null);
      final restored = PhotoMeta.fromDraftJson(draft);
      expect(restored.captureTime, null);
      expect(restored.captureSource, null);
    });
  });
}
