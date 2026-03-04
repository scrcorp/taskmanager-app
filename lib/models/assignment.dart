/// 근무배정(Work Assignment) 데이터 모델
///
/// 직원에게 배정된 일일 근무와 체크리스트를 표현한다.
/// 매장(store) + 근무시간(shift) + 포지션(position) 조합으로 구성.
/// 체크리스트 스냅샷을 포함하여 완료율을 추적한다.
import 'store.dart';
import 'checklist.dart';

/// 페이지네이션된 근무배정 목록 응답
class PaginatedAssignments {
  final List<Assignment> items;
  final int total;
  final int page;
  final int perPage;

  const PaginatedAssignments({
    required this.items,
    required this.total,
    required this.page,
    required this.perPage,
  });

  /// 서버 JSON → PaginatedAssignments 변환
  factory PaginatedAssignments.fromJson(Map<String, dynamic> json) {
    return PaginatedAssignments(
      items: (json['items'] as List).map((e) => Assignment.fromJson(e as Map<String, dynamic>)).toList(),
      total: json['total'] ?? 0,
      page: json['page'] ?? 1,
      perPage: json['per_page'] ?? 20,
    );
  }
}

/// 근무배정 본체
class Assignment {
  final String id;
  final Store store;
  final ShiftInfo shift;
  final PositionInfo position;
  /// 상태: 'assigned', 'in_progress', 'completed'
  final String status;
  final DateTime workDate;
  final int totalItems;
  final int completedItems;
  /// 체크리스트 스냅샷 (항목 목록 + 완료 상태)
  final ChecklistSnapshot? checklistSnapshot;
  final DateTime? createdAt;

  const Assignment({
    required this.id,
    required this.store,
    required this.shift,
    required this.position,
    required this.status,
    required this.workDate,
    this.totalItems = 0,
    this.completedItems = 0,
    this.checklistSnapshot,
    this.createdAt,
  });

  /// "매장명 · 시프트명 · 포지션명" 형식의 라벨
  String get label => '${store.name} · ${shift.name} · ${position.name}';

  /// 상태를 사용자에게 표시할 라벨로 변환
  String get statusLabel {
    switch (status) {
      case 'assigned':
        return 'Pending';
      case 'in_progress':
        return 'In Progress';
      case 'completed':
        return 'Completed';
      default:
        return status;
    }
  }

  /// 서버 JSON → Assignment 객체 변환
  ///
  /// checklist_snapshot이 List(구버전)인지 Map(신버전)인지에 따라
  /// 다른 팩토리 메서드로 파싱한다.
  factory Assignment.fromJson(Map<String, dynamic> json) {
    final checklistRaw = json['checklist_snapshot'];
    ChecklistSnapshot? checklist;
    if (checklistRaw is List) {
      checklist = ChecklistSnapshot.fromItemsList(checklistRaw);
    } else if (checklistRaw is Map<String, dynamic>) {
      checklist = ChecklistSnapshot.fromJson(checklistRaw);
    }

    return Assignment(
      id: json['id'],
      // store가 중첩 객체 또는 개별 필드로 올 수 있어 양쪽 처리
      store: Store.fromJson(json['store'] ?? {
        'id': json['store_id'] ?? '',
        'name': json['store_name'] ?? '',
      }),
      shift: ShiftInfo.fromJson(json['shift'] ?? {
        'id': json['shift_id'],
        'name': json['shift_name'] ?? '',
      }),
      position: PositionInfo.fromJson(json['position'] ?? {
        'id': json['position_id'],
        'name': json['position_name'] ?? '',
      }),
      status: json['status'] ?? 'assigned',
      workDate: DateTime.parse(json['work_date']),
      totalItems: json['total_items'] ?? checklist?.totalItems ?? 0,
      completedItems: json['completed_items'] ?? checklist?.completedItems ?? 0,
      checklistSnapshot: checklist,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
    );
  }
}

/// 근무 시프트 정보
///
/// 시프트 이름에서 시간 범위를 파싱하여
/// 현재 시간이 근무시간 내인지 판별할 수 있다.
/// 예: "Open 09:00~17:00" → startTime: 9:00, endTime: 17:00
class ShiftInfo {
  final String? id;
  final String name;

  const ShiftInfo({this.id, required this.name});

  /// 시프트 이름에서 시간 범위를 추출하는 정규식
  /// "HH:MM - HH:MM" 또는 "HH:MM~HH:MM" 패턴 지원
  static final _timeRangeRegex = RegExp(r'(\d{1,2}):(\d{2})\s*[-~]\s*(\d{1,2}):(\d{2})');

  /// 시프트 시작 시간 (파싱 실패 시 null)
  ({int hour, int minute})? get startTime {
    final match = _timeRangeRegex.firstMatch(name);
    if (match == null) return null;
    return (hour: int.parse(match.group(1)!), minute: int.parse(match.group(2)!));
  }

  /// 시프트 종료 시간 (파싱 실패 시 null)
  ({int hour, int minute})? get endTime {
    final match = _timeRangeRegex.firstMatch(name);
    if (match == null) return null;
    return (hour: int.parse(match.group(3)!), minute: int.parse(match.group(4)!));
  }

  /// 주어진 시간이 이 시프트의 근무시간 범위 내인지 확인
  ///
  /// 야간 시프트(종료 < 시작)도 처리한다.
  /// 시간 파싱 실패 시 true를 반환 (안전한 기본값).
  bool isWithinShiftHours(DateTime dateTime) {
    final start = startTime;
    final end = endTime;
    if (start == null || end == null) return true;
    final nowMin = dateTime.hour * 60 + dateTime.minute;
    final startMin = start.hour * 60 + start.minute;
    final endMin = end.hour * 60 + end.minute;
    // 야간 시프트: 종료시간 < 시작시간 (예: 22:00~06:00)
    if (endMin < startMin) {
      return nowMin >= startMin || nowMin <= endMin;
    }
    return nowMin >= startMin && nowMin <= endMin;
  }

  /// 서버 JSON → ShiftInfo 변환
  factory ShiftInfo.fromJson(Map<String, dynamic> json) {
    return ShiftInfo(id: json['id'], name: json['name'] ?? '');
  }
}

/// 포지션(직무) 정보
class PositionInfo {
  final String? id;
  final String name;

  const PositionInfo({this.id, required this.name});

  /// 서버 JSON → PositionInfo 변환
  factory PositionInfo.fromJson(Map<String, dynamic> json) {
    return PositionInfo(id: json['id'], name: json['name'] ?? '');
  }
}
