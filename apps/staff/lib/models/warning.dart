/// 경고(Warning) 데이터 모델 — staff 본인의 active 경고.
///
/// Acknowledge 는 자동이다: 상세 GET 호출 시 서버가 자동으로 acknowledge 처리한다.
/// staff 가 명시적으로 하는 유일한 액션은 SIGN(서명) 이다.
/// 배지/독촉은 employee 서명이 없는 경우(signatures.employee == null)로 판단한다.
///
/// 서명은 벡터 stroke(0..1 로 정규화된 점 배열) + aspect 로 저장된다.

/// 정규화된 서명 stroke 묶음.
///
/// strokes: 각 stroke 는 [x, y] 점들의 리스트. 좌표는 0..1 로 정규화되어 있어
/// 어떤 크기의 캔버스에서도 동일하게 렌더링된다.
/// aspect: stroke 를 캡처한 패드의 width/height 비율 (null 이면 정사각형 가정).
class SignatureStrokes {
  final List<List<List<double>>> strokes;
  final double? aspect;

  const SignatureStrokes({required this.strokes, this.aspect});

  factory SignatureStrokes.fromJson(Map<String, dynamic> json) {
    final rawStrokes = (json['strokes'] as List?) ?? const [];
    return SignatureStrokes(
      strokes: rawStrokes.map<List<List<double>>>((stroke) {
        return (stroke as List).map<List<double>>((point) {
          final p = point as List;
          return [
            (p[0] as num).toDouble(),
            (p[1] as num).toDouble(),
          ];
        }).toList();
      }).toList(),
      aspect: (json['aspect'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'strokes': strokes,
        'aspect': aspect,
      };

  bool get isEmpty => strokes.isEmpty || strokes.every((s) => s.isEmpty);
}

/// 단일 서명 정보 (직원 또는 매니저).
class SigInfo {
  final String? signerUserId;
  final String? signerName;
  final DateTime? signedAt;

  /// 'drawn' (새로 그림) 또는 'saved' (저장된 서명 재사용).
  final String? method;
  final SignatureStrokes? signatureStrokes;

  const SigInfo({
    this.signerUserId,
    this.signerName,
    this.signedAt,
    this.method,
    this.signatureStrokes,
  });

  factory SigInfo.fromJson(Map<String, dynamic> json) {
    return SigInfo(
      signerUserId: json['signer_user_id']?.toString(),
      signerName: json['signer_name'] as String?,
      signedAt: json['signed_at'] != null
          ? DateTime.parse(json['signed_at'] as String)
          : null,
      method: json['method'] as String?,
      signatureStrokes: json['signature_strokes'] != null
          ? SignatureStrokes.fromJson(
              json['signature_strokes'] as Map<String, dynamic>)
          : null,
    );
  }
}

/// 경고(Warning) — staff 본인에게 발행된 active 경고.
class Warning {
  final String id;
  final String refNo;
  final String status;
  final String? subjectName;
  final String? employeeNo;
  final String? issuedByName;
  final String? storeName;
  final String title;

  /// 사유 코드 리스트 (예: 'tardiness', 'policy_violation').
  final List<String> categories;

  /// 사유 코드 → 표시 라벨 매핑 (서버가 제공).
  final Map<String, String> categoryLabels;

  final String? details;
  final String? correctiveAction;
  final String? otherText;
  final DateTime? deadline;
  final DateTime? followUpDate;
  final String? followUpTime;
  final DateTime? warningDate;

  /// 경고 차수 (1=first, 2=second, ...). 라벨은 ordinal 로 파생.
  final int? ordinal;

  final DateTime? acknowledgedAt;
  final SigInfo? employeeSignature;
  final SigInfo? managerSignature;
  final DateTime? createdAt;

  /// 서명 방식: 'digital' (앱 내 벡터 서명) 또는 'wet' (실물 서명 후 PDF 업로드).
  final String signatureMethod;

  /// 스토어 코드 (파일명/표시용, 서버가 제공). 없으면 null.
  final String? storeCode;

  /// wet 방식에서 서명된 PDF 가 업로드되어 있는지 여부.
  final bool signedPdfPresent;

  /// wet 문서상 서명일 (업로더 입력, 폴백=업로드일). 없으면 null.
  final DateTime? wetSignedOn;

  /// wet PDF 업로드 시각. 없으면 null.
  final DateTime? wetUploadedAt;

  /// 직원 서명 완료 여부 (서버 파생: digital=벡터 서명행 존재 / wet=PDF 업로드).
  /// 서명 상태 판단은 항상 이 값을 사용한다.
  final bool employeeSigned;

  /// 매니저 서명 완료 여부 (서버 파생: digital=매니저 서명행 / wet=PDF 업로드).
  final bool managerSigned;

  const Warning({
    required this.id,
    required this.refNo,
    required this.status,
    this.subjectName,
    this.employeeNo,
    this.issuedByName,
    this.storeName,
    required this.title,
    this.categories = const [],
    this.categoryLabels = const {},
    this.details,
    this.correctiveAction,
    this.otherText,
    this.deadline,
    this.followUpDate,
    this.followUpTime,
    this.warningDate,
    this.ordinal,
    this.acknowledgedAt,
    this.employeeSignature,
    this.managerSignature,
    this.createdAt,
    this.signatureMethod = 'digital',
    this.storeCode,
    this.signedPdfPresent = false,
    this.wetSignedOn,
    this.wetUploadedAt,
    this.employeeSigned = false,
    this.managerSigned = false,
  });

  /// wet 서명 방식 여부.
  bool get isWet => signatureMethod == 'wet';

  /// 직원 서명 완료 여부. wet/digital 모두 서버 파생 [employeeSigned] 를 신뢰하되,
  /// 레거시 응답(필드 부재) 호환을 위해 벡터 서명행 존재도 함께 본다.
  bool get isSigned => employeeSigned || employeeSignature != null;

  /// 카테고리 코드 → 사람이 읽을 라벨 (서버 라벨 우선, 없으면 코드 그대로).
  String labelFor(String code) => categoryLabels[code] ?? code;

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    final s = v.toString();
    if (s.isEmpty) return null;
    return DateTime.tryParse(s);
  }

  factory Warning.fromJson(Map<String, dynamic> json) {
    final sigs = (json['signatures'] as Map?)?.cast<String, dynamic>() ?? {};
    return Warning(
      id: json['id'].toString(),
      refNo: json['ref_no']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      subjectName: json['subject_name'] as String?,
      employeeNo: json['employee_no']?.toString(),
      issuedByName: json['issued_by_name'] as String?,
      storeName: json['store_name'] as String?,
      title: json['title']?.toString() ?? '',
      categories: ((json['categories'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList(),
      categoryLabels:
          ((json['category_labels'] as Map?)?.cast<String, dynamic>() ?? {})
              .map((k, v) => MapEntry(k, v.toString())),
      details: json['details'] as String?,
      correctiveAction: json['corrective_action'] as String?,
      otherText: json['other_text'] as String?,
      deadline: _parseDate(json['deadline']),
      followUpDate: _parseDate(json['follow_up_date']),
      followUpTime: json['follow_up_time'] as String?,
      warningDate: _parseDate(json['warning_date']),
      ordinal: (json['ordinal'] as num?)?.toInt(),
      acknowledgedAt: _parseDate(json['acknowledged_at']),
      employeeSignature: sigs['employee'] != null
          ? SigInfo.fromJson((sigs['employee'] as Map).cast<String, dynamic>())
          : null,
      managerSignature: sigs['manager'] != null
          ? SigInfo.fromJson((sigs['manager'] as Map).cast<String, dynamic>())
          : null,
      createdAt: _parseDate(json['created_at']),
      signatureMethod: json['signature_method']?.toString() ?? 'digital',
      storeCode: json['store_code'] as String?,
      signedPdfPresent: json['signed_pdf_present'] == true,
      wetSignedOn: _parseDate(json['wet_signed_on']),
      wetUploadedAt: _parseDate(json['wet_uploaded_at']),
      employeeSigned: json['employee_signed'] == true,
      managerSigned: json['manager_signed'] == true,
    );
  }
}
