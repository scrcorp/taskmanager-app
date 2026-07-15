import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:app/utils/photo_capture.dart';

/// EXIF DateTimeOriginal 이 박힌 작은 JPEG 바이트를 생성한다(테스트 픽스처).
Uint8List _jpegWithExif(String dateTimeOriginal, {int w = 4, int h = 4}) {
  final im = img.Image(width: w, height: h);
  im.exif.exifIfd['DateTimeOriginal'] = dateTimeOriginal;
  return img.encodeJpg(im);
}

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
    test('카메라: EXIF 없으면 주입된 now 의 UTC 를 셔터 시각으로 사용', () async {
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

    test('EXIF 촬영시각이 있으면 갤러리에서 그 값을 사용', () async {
      final bytes = _jpegWithExif('2026:03:10 08:15:30');
      final result = await resolveCaptureTime(ImageSource.gallery, bytes);
      expect(result, DateTime(2026, 3, 10, 8, 15, 30).toUtc());
    });

    test('EXIF 촬영시각이 있으면 카메라 source 여도 now 가 아니라 EXIF 를 사용 '
        '(데스크톱 파일피커로 폰 사진을 고른 경우)', () async {
      final bytes = _jpegWithExif('2026:03:10 08:15:30');
      final now = DateTime(2026, 6, 22, 9, 0, 0);
      final result =
          await resolveCaptureTime(ImageSource.camera, bytes, now: now);
      expect(result, DateTime(2026, 3, 10, 8, 15, 30).toUtc());
    });
  });

  group('resizeForUpload', () {
    test('긴 변이 maxDim 을 넘으면 축소하고 다시 디코드 가능한 JPEG 를 반환', () {
      final big = img.encodeJpg(img.Image(width: 4000, height: 3000));
      final out = resizeForUpload(big, maxDim: 2048);
      final decoded = img.decodeImage(out);
      expect(decoded, isNotNull);
      expect(decoded!.width, 2048);
      expect(decoded.height, 1536);
    });

    test('maxDim 이하 이미지는 확대하지 않는다', () {
      final small = img.encodeJpg(img.Image(width: 800, height: 600));
      final out = resizeForUpload(small, maxDim: 2048);
      final decoded = img.decodeImage(out)!;
      expect(decoded.width, 800);
      expect(decoded.height, 600);
    });

    test('디코드 불가한 바이트(비이미지)는 원본 그대로 반환', () {
      final junk = Uint8List.fromList([0, 1, 2, 3, 4]);
      expect(resizeForUpload(junk), junk);
    });
  });
}
