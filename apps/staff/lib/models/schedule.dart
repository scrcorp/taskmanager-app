/// 스케줄 관련 데이터 모델
///
/// 업무역할(WorkRole), 스케줄 신청(Request), 확정 스케줄(Entry),
/// 템플릿(Template)을 표현한다.

/// 매장 업무역할 — shift + position 조합
class WorkRole {
  final String id;
  final String storeId;
  final String shiftId;
  final String? shiftName;
  final String positionId;
  final String? positionName;
  final String? name;
  final String? defaultStartTime;
  final String? defaultEndTime;
  final bool isActive;

  const WorkRole({
    required this.id,
    required this.storeId,
    required this.shiftId,
    this.shiftName,
    required this.positionId,
    this.positionName,
    this.name,
    this.defaultStartTime,
    this.defaultEndTime,
    this.isActive = true,
  });

  String get displayName =>
      name ?? '${shiftName ?? ''} · ${positionName ?? ''}'.trim();

  factory WorkRole.fromJson(Map<String, dynamic> json) {
    return WorkRole(
      id: json['id'],
      storeId: json['store_id'],
      shiftId: json['shift_id'],
      shiftName: json['shift_name'],
      positionId: json['position_id'],
      positionName: json['position_name'],
      name: json['name'],
      defaultStartTime: json['default_start_time'],
      defaultEndTime: json['default_end_time'],
      isActive: json['is_active'] ?? true,
    );
  }
}

/// 스케줄 신청
class ScheduleRequest {
  final String id;
  final String userId;
  final String storeId;
  final String? storeName;
  final String? workRoleId;
  final String? workRoleName;
  final DateTime workDate;
  final String? preferredStartTime;
  final String? preferredEndTime;
  final String? breakStartTime;
  final String? breakEndTime;
  final String? note;
  final String status; // submitted, accepted, modified, rejected
  final DateTime? submittedAt;
  final DateTime createdAt;
  // modified 상태일 때 원본 시간 (서버: original_preferred_start/end_time)
  final String? originalStartTime;
  final String? originalEndTime;
  final String? rejectedReason;

  const ScheduleRequest({
    required this.id,
    required this.userId,
    required this.storeId,
    this.storeName,
    this.workRoleId,
    this.workRoleName,
    required this.workDate,
    this.preferredStartTime,
    this.preferredEndTime,
    this.breakStartTime,
    this.breakEndTime,
    this.note,
    required this.status,
    this.submittedAt,
    required this.createdAt,
    this.originalStartTime,
    this.originalEndTime,
    this.rejectedReason,
  });

  String get statusLabel {
    switch (status) {
      case 'submitted':
        return 'Submitted';
      case 'accepted':
        return 'Approved';
      case 'modified':
        return 'Modified';
      case 'rejected':
        return 'Rejected';
      default:
        return status;
    }
  }

  factory ScheduleRequest.fromJson(Map<String, dynamic> json) {
    return ScheduleRequest(
      id: json['id'],
      userId: json['user_id'],
      storeId: json['store_id'],
      storeName: json['store_name'],
      workRoleId: json['work_role_id'],
      workRoleName: json['work_role_name'],
      workDate: DateTime.parse(json['work_date']),
      preferredStartTime: json['preferred_start_time'],
      preferredEndTime: json['preferred_end_time'],
      breakStartTime: json['break_start_time'],
      breakEndTime: json['break_end_time'],
      note: json['note'],
      status: json['status'] ?? 'submitted',
      submittedAt: json['submitted_at'] != null
          ? DateTime.parse(json['submitted_at'])
          : null,
      createdAt: DateTime.parse(json['created_at']),
      originalStartTime: json['original_preferred_start_time'],
      originalEndTime: json['original_preferred_end_time'],
      rejectedReason: json['rejection_reason'],
    );
  }
}

/// 확정된 스케줄 엔트리
class ScheduleEntry {
  final String id;
  final String userId;
  final String? userName;
  final String storeId;
  final String? storeName;
  final String? workRoleId;
  final String? workRoleName;
  final DateTime workDate;
  final String startTime;
  final String endTime;
  final String? breakStartTime;
  final String? breakEndTime;
  final int netWorkMinutes;
  final String status;
  final String? note;
  final String? requestId; // 신청 기반 엔트리의 원본 request ID (중복 제거용)
  final DateTime createdAt;
  final String? checklistInstanceId; // 배정된 체크리스트 인스턴스 ID
  final int totalItems; // 체크리스트 총 항목 수 (0이면 체크리스트 없음)

  const ScheduleEntry({
    required this.id,
    required this.userId,
    this.userName,
    required this.storeId,
    this.storeName,
    this.workRoleId,
    this.workRoleName,
    required this.workDate,
    required this.startTime,
    required this.endTime,
    this.breakStartTime,
    this.breakEndTime,
    required this.netWorkMinutes,
    required this.status,
    this.note,
    this.requestId,
    required this.createdAt,
    this.checklistInstanceId,
    this.totalItems = 0,
  });

  bool get hasBreak => breakStartTime != null && breakEndTime != null &&
      breakStartTime!.isNotEmpty && breakEndTime!.isNotEmpty;

  String get timeRange => hasBreak
      ? '$startTime–$breakStartTime · $breakEndTime–$endTime'
      : '$startTime – $endTime';

  String get netWorkDisplay {
    final h = netWorkMinutes ~/ 60;
    final m = netWorkMinutes % 60;
    if (m == 0) return '${h}시간';
    return '${h}시간 ${m}분';
  }

  factory ScheduleEntry.fromJson(Map<String, dynamic> json) {
    return ScheduleEntry(
      id: json['id'],
      userId: json['user_id'],
      userName: json['user_name'],
      storeId: json['store_id'],
      storeName: json['store_name'],
      workRoleId: json['work_role_id'],
      workRoleName: json['work_role_name'],
      workDate: DateTime.parse(json['work_date']),
      startTime: json['start_time'] ?? '',
      endTime: json['end_time'] ?? '',
      breakStartTime: json['break_start_time'],
      breakEndTime: json['break_end_time'],
      netWorkMinutes: json['net_work_minutes'] ?? 0,
      status: json['status'] ?? 'draft',
      note: json['note'],
      requestId: json['request_id'],
      createdAt: DateTime.parse(json['created_at']),
      checklistInstanceId: json['checklist_instance_id'],
      totalItems: json['total_items'] ?? 0,
    );
  }
}

/// 스케줄 템플릿
class ScheduleTemplate {
  final String id;
  final String name;
  final bool isDefault;
  final String? storeId;
  final List<ScheduleTemplateItem> items;

  const ScheduleTemplate({
    required this.id,
    required this.name,
    this.isDefault = false,
    this.storeId,
    required this.items,
  });

  factory ScheduleTemplate.fromJson(Map<String, dynamic> json) {
    return ScheduleTemplate(
      id: json['id'],
      name: json['name'],
      isDefault: json['is_default'] ?? json['isDefault'] ?? false,
      storeId: json['store_id'] ?? json['storeId'],
      items: (json['items'] as List? ?? [])
          .map((e) => ScheduleTemplateItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// 템플릿 항목 (요일별 설정)
class ScheduleTemplateItem {
  final int dayOfWeek; // 0=Sun, 6=Sat
  final String workRoleId;
  final String? workRoleName;
  final String? storeName;
  final String preferredStartTime;
  final String preferredEndTime;

  const ScheduleTemplateItem({
    required this.dayOfWeek,
    required this.workRoleId,
    this.workRoleName,
    this.storeName,
    required this.preferredStartTime,
    required this.preferredEndTime,
  });

  factory ScheduleTemplateItem.fromJson(Map<String, dynamic> json) {
    return ScheduleTemplateItem(
      dayOfWeek: json['day_of_week'] ?? json['dayOfWeek'],
      workRoleId: json['work_role_id'] ?? json['workRoleId'],
      workRoleName: json['work_role_name'] ?? json['workRoleName'],
      storeName: json['store_name'] ?? json['storeName'],
      preferredStartTime:
          json['preferred_start_time'] ?? json['preferredStartTime'],
      preferredEndTime:
          json['preferred_end_time'] ?? json['preferredEndTime'],
    );
  }
}
