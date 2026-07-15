/// 사진 촬영시각·출처(capture metadata) 추출 유틸.
///
/// 워터마크에 표시하는 시각은 "사진이 찍힌 시점"(capture_time)이다. 서버 수신시각이 아니다.
///
/// capture_time 결정 우선순위 (source 무관):
///  1) 바이트의 EXIF DateTimeOriginal → 그 값(진짜 촬영시각).
///     갤러리 사진·데스크톱 파일피커로 고른 폰 사진 모두 여기서 잡힌다.
///  2) EXIF 없고 라이브 카메라(ImageSource.camera) → 현재 시각(셔터 시각).
///  3) 그 외(갤러리인데 EXIF 없음) → null(시각 미상).
///
/// ⚠️ EXIF 는 반드시 "리사이즈 전 원본 바이트"에서 읽어야 한다. image_picker 의
/// maxWidth/maxHeight/imageQuality 로 리사이즈하면 EXIF 가 통째로 사라지므로,
/// 화면 코드는 원본으로 픽 → EXIF 읽기 → [resizeForUpload] 순서를 지켜야 한다.
///
/// capture_time 은 클라가 주장하는 값이라 위조 가능하다. 신뢰 기준(received_at)은 서버가 따로 기록한다.
library;

import 'dart:typed_data';

import 'package:exif/exif.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

/// 출처 문자열 — 서버 capture_source 값.
String captureSourceOf(ImageSource source) =>
    source == ImageSource.camera ? 'live' : 'gallery';

/// EXIF DateTimeOriginal 문자열("YYYY:MM:DD HH:MM:SS")을 UTC DateTime 으로 파싱.
///
/// EXIF 시각엔 타임존이 없으므로 기기 로컬 시각으로 간주하고 UTC 로 변환한다.
/// 형식이 어긋나거나 비어 있으면 null.
DateTime? parseExifDateTime(String? raw) {
  if (raw == null) return null;
  final trimmed = raw.trim();
  // 형식: "2026:06:22 14:30:05"
  final match = RegExp(r'^(\d{4}):(\d{2}):(\d{2})\s+(\d{2}):(\d{2}):(\d{2})')
      .firstMatch(trimmed);
  if (match == null) return null;
  try {
    final local = DateTime(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
      int.parse(match.group(4)!),
      int.parse(match.group(5)!),
      int.parse(match.group(6)!),
    );
    return local.toUtc();
  } catch (_) {
    return null;
  }
}

/// 이미지 바이트에서 EXIF DateTimeOriginal 을 읽어 UTC DateTime 으로 반환. 실패 시 null.
Future<DateTime?> readExifCaptureTime(List<int> bytes) async {
  try {
    final tags = await readExifFromBytes(bytes);
    final original = tags['EXIF DateTimeOriginal'] ?? tags['Image DateTime'];
    return parseExifDateTime(original?.printable);
  } catch (_) {
    return null;
  }
}

/// 선택한 사진 1장의 촬영시각을 결정한다. (우선순위는 파일 상단 doc 참고)
///
/// [bytes] 는 반드시 리사이즈 전 원본이어야 한다(EXIF 보존).
/// [now] 는 라이브 셔터 시각 주입용(테스트). 생략하면 현재 시각(UTC).
Future<DateTime?> resolveCaptureTime(
  ImageSource source,
  List<int> bytes, {
  DateTime? now,
}) async {
  // 1) EXIF 촬영시각이 있으면 무조건 그 값(source 무관).
  //    데스크톱에서 "Take Photo" 가 파일피커로 뜨더라도, 고른 폰 사진의
  //    EXIF 촬영시각이 잡히므로 "고른 시각"이 아니라 진짜 촬영시각이 들어간다.
  final exifTime = await readExifCaptureTime(bytes);
  if (exifTime != null) return exifTime;
  // 2) EXIF 없고 라이브 카메라 → 셔터 시각.
  if (source == ImageSource.camera) {
    return (now ?? DateTime.now()).toUtc();
  }
  // 3) 갤러리인데 EXIF 없음 → 시각 미상.
  return null;
}

/// 업로드 직전 클라이언트 리사이즈. **[resolveCaptureTime] 으로 EXIF 를 읽은 뒤** 호출한다
/// (리사이즈는 EXIF 를 버리므로 순서가 중요).
///
/// - 긴 변을 [maxDim] 이하로 줄이고 JPEG([quality])로 재인코딩한다(서버가 WebP q80/2048 로 최종 가공).
/// - EXIF orientation 을 픽셀에 bake 한다 → EXIF 를 버려도 이미지가 눕지 않는다.
/// - 디코드 실패(예: HEIC 등 미지원 포맷) 시 원본 바이트를 그대로 반환한다.
Uint8List resizeForUpload(
  Uint8List bytes, {
  int maxDim = 2048,
  int quality = 90,
}) {
  img.Image? decoded;
  try {
    decoded = img.decodeImage(bytes);
  } catch (_) {
    decoded = null; // 손상/미지원 포맷은 decodeImage 가 throw 하기도 함
  }
  if (decoded == null) return bytes; // 미지원 포맷 → 원본 그대로(서버가 가공)
  final baked = img.bakeOrientation(decoded);
  final img.Image sized = (baked.width > maxDim || baked.height > maxDim)
      ? img.copyResize(
          baked,
          width: baked.width >= baked.height ? maxDim : null,
          height: baked.height > baked.width ? maxDim : null,
        )
      : baked;
  return img.encodeJpg(sized, quality: quality);
}
