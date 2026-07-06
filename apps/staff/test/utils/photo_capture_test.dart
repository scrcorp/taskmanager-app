import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:app/utils/photo_capture.dart';

void main() {
  group('captureSourceOf', () {
    test('카메라 → live', () {
      expect(captureSourceOf(ImageSource.camera), 'live');
    });
    test('갤러리 → gallery', () {
      expect(captureSourceOf(ImageSource.gallery), 'gallery');
    });
  });

  group('parseExifDateTime', () {
    test('정상 EXIF 문자열을 로컬→UTC 로 파싱', () {
      final result = parseExifDateTime('2026:06:22 14:30:05');
      // 로컬로 해석 후 UTC 변환 → 동일 순간
      expect(result, DateTime(2026, 6, 22, 14, 30, 5).toUtc());
      expect(result!.isUtc, true);
    });

    test('초 뒤 잉여 문자(타임존 등)가 붙어도 앞부분만 파싱', () {
      final result = parseExifDateTime('2026:06:22 14:30:05+09:00');
      expect(result, DateTime(2026, 6, 22, 14, 30, 5).toUtc());
    });

    test('null → null', () {
      expect(parseExifDateTime(null), null);
    });

    test('빈 문자열 → null', () {
      expect(parseExifDateTime('   '), null);
    });

    test('형식 불일치(대시 구분) → null', () {
      expect(parseExifDateTime('2026-06-22 14:30:05'), null);
    });

    test('형식 불일치(시각 누락) → null', () {
      expect(parseExifDateTime('2026:06:22'), null);
    });
  });

  group('readExifCaptureTime', () {
    test('EXIF 없는 바이트(빈/비이미지) → null (graceful)', () async {
      expect(await readExifCaptureTime(<int>[]), null);
      expect(await readExifCaptureTime([0, 1, 2, 3, 4]), null);
    });
  });

  group('resolveCaptureTime', () {
    test('카메라: 주입된 now 의 UTC 를 셔터 시각으로 사용 (바이트 무시)', () async {
      final now = DateTime(2026, 6, 22, 9, 0, 0);
      final result = await resolveCaptureTime(
        ImageSource.camera,
        <int>[],
        now: now,
      );
      expect(result, now.toUtc());
      expect(result!.isUtc, true);
    });

    test('갤러리: EXIF 없으면 null', () async {
      final result = await resolveCaptureTime(ImageSource.gallery, <int>[]);
      expect(result, null);
    });
  });
}
