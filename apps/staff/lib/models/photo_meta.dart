/// 업로드한 사진 1장의 메타데이터.
///
/// 체크리스트 완료/재제출 시 서버로 보내는 `photos` 항목 단위다.
/// - [key]: 업로드 후 받은 파일 키(file_url). 서버가 이 키를 정규화·확정 저장한다.
/// - [captureTime]: 클라가 주장하는 촬영 시각(라이브=셔터, 갤러리=EXIF DateTimeOriginal).
///   알 수 없으면 null — 서버는 받되 capture_source="unknown" 으로 플래그한다.
/// - [captureSource]: 출처. 'live'(라이브 카메라) | 'gallery'(갤러리). 모르면 null.
///
/// 워터마크는 클라이언트 표시 오버레이로만 그린다. 픽셀에 굽지 않는다.
class PhotoMeta {
  final String key;
  final DateTime? captureTime;
  final String? captureSource;

  const PhotoMeta({
    required this.key,
    this.captureTime,
    this.captureSource,
  });

  /// 서버 payload 변환 — null 필드는 생략한다(서버가 unknown 으로 정규화).
  Map<String, dynamic> toJson() {
    return {
      'key': key,
      if (captureTime != null) 'capture_time': captureTime!.toUtc().toIso8601String(),
      if (captureSource != null) 'capture_source': captureSource,
    };
  }

  /// 로컬 draft 직렬화 — capture_time 복원을 위해 null 도 명시 저장.
  Map<String, dynamic> toDraftJson() {
    return {
      'key': key,
      'capture_time': captureTime?.toIso8601String(),
      'capture_source': captureSource,
    };
  }

  factory PhotoMeta.fromDraftJson(Map<String, dynamic> json) {
    return PhotoMeta(
      key: json['key'] as String,
      captureTime: json['capture_time'] != null
          ? DateTime.tryParse(json['capture_time'] as String)
          : null,
      captureSource: json['capture_source'] as String?,
    );
  }
}
