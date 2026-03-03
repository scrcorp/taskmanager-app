import 'store.dart';
import 'checklist.dart';

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

  factory PaginatedAssignments.fromJson(Map<String, dynamic> json) {
    return PaginatedAssignments(
      items: (json['items'] as List).map((e) => Assignment.fromJson(e as Map<String, dynamic>)).toList(),
      total: json['total'] ?? 0,
      page: json['page'] ?? 1,
      perPage: json['per_page'] ?? 20,
    );
  }
}

class Assignment {
  final String id;
  final Store store;
  final ShiftInfo shift;
  final PositionInfo position;
  final String status;
  final DateTime workDate;
  final int totalItems;
  final int completedItems;
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

  String get label => '${store.name} · ${shift.name} · ${position.name}';

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

class ShiftInfo {
  final String? id;
  final String name;

  const ShiftInfo({this.id, required this.name});

  static final _timeRangeRegex = RegExp(r'(\d{1,2}):(\d{2})\s*[-~]\s*(\d{1,2}):(\d{2})');

  ({int hour, int minute})? get startTime {
    final match = _timeRangeRegex.firstMatch(name);
    if (match == null) return null;
    return (hour: int.parse(match.group(1)!), minute: int.parse(match.group(2)!));
  }

  ({int hour, int minute})? get endTime {
    final match = _timeRangeRegex.firstMatch(name);
    if (match == null) return null;
    return (hour: int.parse(match.group(3)!), minute: int.parse(match.group(4)!));
  }

  bool isWithinShiftHours(DateTime dateTime) {
    final start = startTime;
    final end = endTime;
    if (start == null || end == null) return true;
    final nowMin = dateTime.hour * 60 + dateTime.minute;
    final startMin = start.hour * 60 + start.minute;
    final endMin = end.hour * 60 + end.minute;
    if (endMin < startMin) {
      return nowMin >= startMin || nowMin <= endMin;
    }
    return nowMin >= startMin && nowMin <= endMin;
  }

  factory ShiftInfo.fromJson(Map<String, dynamic> json) {
    return ShiftInfo(id: json['id'], name: json['name'] ?? '');
  }
}

class PositionInfo {
  final String? id;
  final String name;

  const PositionInfo({this.id, required this.name});

  factory PositionInfo.fromJson(Map<String, dynamic> json) {
    return PositionInfo(id: json['id'], name: json['name'] ?? '');
  }
}
