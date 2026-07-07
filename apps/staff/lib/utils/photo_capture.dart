/// 사진 촬영시각·출처(capture metadata) 추출 유틸.
///
/// 워터마크에 표시하는 시각은 "사진이 찍힌 시점"(capture_time)이다. 서버 수신시각이 아니다.
/// - 라이브 카메라(ImageSource.camera): capture_source="live", capture_time=셔터 시각(현재시각).
/// - 갤러리(ImageSource.gallery): capture_source="gallery", capture_time=EXIF DateTimeOriginal.
///   EXIF 없음/파싱 실패 → capture_time=null (서버가 capture_source 그대로 받되 시각 미상으로 처리).
///
/// capture_time 은 클라가 주장하는 값이라 위조 가능하다. 신뢰 기준(received_at)은 서버가 따로 기록한다.
import 'package:exif/exif.dart';
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

/// 선택한 사진 1장의 촬영시각을 출처에 맞게 결정한다.
///
/// [now] 는 라이브 셔터 시각 주입용(테스트). 생략하면 현재 시각(UTC).
Future<DateTime?> resolveCaptureTime(
  ImageSource source,
  List<int> bytes, {
  DateTime? now,
}) async {
  if (source == ImageSource.camera) {
    return (now ?? DateTime.now()).toUtc();
  }
  return readExifCaptureTime(bytes);
}
