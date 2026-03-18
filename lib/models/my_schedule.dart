/// 내 스케줄(My Schedule) 데이터 모델
///
/// 직원에게 배정된 확정 스케줄과 체크리스트를 표현한다.
/// 매장(store) + 업무역할(work role) 조합으로 구성.
import 'package:flutter/material.dart';
import 'store.dart';
import 'checklist.dart';

/// 체크리스트 카드 상태
enum ChecklistCardStatus {
  notStarted,  // 시작 안 함
  inProgress,  // 진행 중
  pending,     // 전부 완료 + report 보냄, 리뷰 대기
  rejected,    // 미해결 반려 존재
  done,        // 모든 항목 리뷰 통과
}

extension ChecklistCardStatusExt on ChecklistCardStatus {
  String get label => switch (this) {
    ChecklistCardStatus.notStarted => 'Not Started',
    ChecklistCardStatus.inProgress => 'In Progress',
    ChecklistCardStatus.pending => 'Pending Review',
    ChecklistCardStatus.rejected => 'Rejected',
    ChecklistCardStatus.done => 'Done',
  };

  Color get color => switch (this) {
    ChecklistCardStatus.notStarted => const Color(0xFF9CA3AF),
    ChecklistCardStatus.inProgress => const Color(0xFF3B8DD9),
    ChecklistCardStatus.pending => const Color(0xFFF39C12),
    ChecklistCardStatus.rejected => const Color(0xFFFF6B6B),
    ChecklistCardStatus.done => const Color(0xFF00B894),
  };

  Color get bgColor => switch (this) {
    ChecklistCardStatus.notStarted => const Color(0xFFF3F4F6),
    ChecklistCardStatus.inProgress => const Color(0xFFEBF3FD),
    ChecklistCardStatus.pending => const Color(0xFFFEF5E6),
    ChecklistCardStatus.rejected => const Color(0xFFFFEEEE),
    ChecklistCardStatus.done => const Color(0xFFE6F9F4),
  };
}

/// 페이지네이션된 스케줄 목록 응답
class PaginatedMySchedules {
  final List<MySchedule> items;
  final int total;
  final int page;
  final int perPage;

  const PaginatedMySchedules({
    required this.items,
    required this.total,
    required this.page,
    required this.perPage,
  });

  factory PaginatedMySchedules.fromJson(Map<String, dynamic> json) {
    return PaginatedMySchedules(
      items: (json['items'] as List).map((e) => MySchedule.fromJson(e as Map<String, dynamic>)).toList(),
      total: json['total'] ?? 0,
      page: json['page'] ?? 1,
      perPage: json['per_page'] ?? 20,
    );
  }
}

/// 내 스케줄 본체
class MySchedule {
  final String id;
  final Store store;
  final String? workRoleId;
  final String workRoleName;
  final String status;
  final DateTime workDate;
  final String? startTime;
  final String? endTime;
  final String? breakStartTime;
  final String? breakEndTime;
  final int netWorkMinutes;
  final int totalItems;
  final int completedItems;
  final String? checklistInstanceId;
  final ChecklistSnapshot? checklistSnapshot;
  final String? reportedAt;
  final bool hasRejected;
  final bool hasPendingReReview;
  final bool allPassed;
  final String? note;
  final DateTime? createdAt;

  const MySchedule({
    required this.id,
    required this.store,
    this.workRoleId,
    this.workRoleName = '',
    this.checklistInstanceId,
    required this.status,
    required this.workDate,
    this.startTime,
    this.endTime,
    this.breakStartTime,
    this.breakEndTime,
    this.netWorkMinutes = 0,
    this.totalItems = 0,
    this.completedItems = 0,
    this.checklistSnapshot,
    this.reportedAt,
    this.hasRejected = false,
    this.hasPendingReReview = false,
    this.allPassed = false,
    this.note,
    this.createdAt,
  });

  /// 보고서 제출 여부
  bool get isReported => reportedAt != null;

  /// 체크리스트 종합 상태 (우선순위: rejected > pending > inProgress > notStarted > done)
  ChecklistCardStatus get checklistStatus {
    final snapshot = checklistSnapshot;

    // snapshot이 있으면 상세 판단
    if (snapshot != null && snapshot.totalItems > 0) {
      if (snapshot.isAllPassed) return ChecklistCardStatus.done;
      if (snapshot.unresolvedRejections.isNotEmpty) return ChecklistCardStatus.rejected;
      if (snapshot.isAllCompleted && isReported) return ChecklistCardStatus.pending;
      if (snapshot.completedItems > 0) return ChecklistCardStatus.inProgress;
      return ChecklistCardStatus.notStarted;
    }

    // snapshot 없으면 서버 요약 필드로 fallback
    if (totalItems == 0) return ChecklistCardStatus.notStarted;
    if (allPassed) return ChecklistCardStatus.done;
    if (hasRejected) return ChecklistCardStatus.rejected;
    if (isReported && completedItems == totalItems) return ChecklistCardStatus.pending;
    if (completedItems > 0) return ChecklistCardStatus.inProgress;
    return ChecklistCardStatus.notStarted;
  }

  /// "매장명 · 역할명" 형식의 라벨
  String get label => workRoleName.isNotEmpty ? '${store.name} · $workRoleName' : store.name;

  /// 시간 범위 표시 ("09:00~17:00")
  String get timeRange {
    if (startTime == null || endTime == null) return '';
    return '$startTime~$endTime';
  }

  /// 실근무시간 (시간 단위)
  double get netWorkHours => netWorkMinutes / 60;

  /// 상태 라벨
  String get statusLabel {
    switch (status) {
      case 'confirmed':
        return 'Confirmed';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status;
    }
  }

  /// 시작 시간 파싱
  ({int hour, int minute})? get parsedStartTime {
    if (startTime == null) return null;
    final parts = startTime!.split(':');
    if (parts.length < 2) return null;
    return (hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  /// 종료 시간 파싱
  ({int hour, int minute})? get parsedEndTime {
    if (endTime == null) return null;
    final parts = endTime!.split(':');
    if (parts.length < 2) return null;
    return (hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  /// 현재 시간이 근무시간 범위 내인지 확인
  bool isWithinWorkHours(DateTime dateTime) {
    final start = parsedStartTime;
    final end = parsedEndTime;
    if (start == null || end == null) return true;
    final nowMin = dateTime.hour * 60 + dateTime.minute;
    final startMin = start.hour * 60 + start.minute;
    final endMin = end.hour * 60 + end.minute;
    if (endMin < startMin) {
      return nowMin >= startMin || nowMin <= endMin;
    }
    return nowMin >= startMin && nowMin <= endMin;
  }

  factory MySchedule.fromJson(Map<String, dynamic> json) {
    final checklistRaw = json['checklist_snapshot'];
    ChecklistSnapshot? checklist;
    if (checklistRaw is List) {
      checklist = ChecklistSnapshot.fromItemsList(checklistRaw);
    } else if (checklistRaw is Map<String, dynamic>) {
      checklist = ChecklistSnapshot.fromJson(checklistRaw);
    }

    return MySchedule(
      id: json['id'],
      store: Store.fromJson(json['store'] ?? {
        'id': json['store_id'] ?? '',
        'name': json['store_name'] ?? '',
      }),
      workRoleId: json['work_role_id'],
      workRoleName: json['work_role_name'] ?? '',
      status: json['status'] ?? 'confirmed',
      workDate: DateTime.parse(json['work_date']),
      startTime: json['start_time'],
      endTime: json['end_time'],
      breakStartTime: json['break_start_time'],
      breakEndTime: json['break_end_time'],
      netWorkMinutes: json['net_work_minutes'] ?? 0,
      totalItems: json['total_items'] ?? checklist?.totalItems ?? 0,
      completedItems: json['completed_items'] ?? checklist?.completedItems ?? 0,
      checklistInstanceId: json['checklist_instance_id'],
      checklistSnapshot: checklist,
      reportedAt: json['reported_at'],
      hasRejected: json['has_rejected'] ?? false,
      hasPendingReReview: json['has_pending_re_review'] ?? false,
      allPassed: json['all_passed'] ?? false,
      note: json['note'],
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
    );
  }
}
