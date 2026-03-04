/// 근무배정(Assignment) 상태 관리 Provider
///
/// 오늘의 근무배정, 과거 근무배정, 체크리스트 항목 완료/반려 응답을 관리.
/// WorkScreen과 ChecklistScreen에서 사용.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/assignment.dart';
import '../services/assignment_service.dart';

/// 근무배정 상태 데이터
class AssignmentState {
  /// 오늘의 근무배정 목록
  final List<Assignment> assignments;
  /// 과거 근무배정 (페이지네이션 결과)
  final PaginatedAssignments? pastResult;
  /// 현재 상세 보기 중인 근무배정
  final Assignment? selected;
  final bool isLoading;
  /// 과거 배정 별도 로딩 상태
  final bool isPastLoading;
  final String? error;

  const AssignmentState({
    this.assignments = const [],
    this.pastResult,
    this.selected,
    this.isLoading = false,
    this.isPastLoading = false,
    this.error,
  });

  /// 과거 근무배정 항목 목록 (편의 접근자)
  List<Assignment> get pastAssignments => pastResult?.items ?? [];

  AssignmentState copyWith({
    List<Assignment>? assignments,
    PaginatedAssignments? pastResult,
    Assignment? selected,
    bool? isLoading,
    bool? isPastLoading,
    String? error,
  }) {
    return AssignmentState(
      assignments: assignments ?? this.assignments,
      pastResult: pastResult ?? this.pastResult,
      selected: selected ?? this.selected,
      isLoading: isLoading ?? this.isLoading,
      isPastLoading: isPastLoading ?? this.isPastLoading,
      error: error,
    );
  }
}

/// 근무배정 Provider
final assignmentProvider =
    StateNotifierProvider<AssignmentNotifier, AssignmentState>((ref) {
  return AssignmentNotifier(ref.read(assignmentServiceProvider));
});

/// 근무배정 상태 관리 Notifier
class AssignmentNotifier extends StateNotifier<AssignmentState> {
  final AssignmentService _service;

  AssignmentNotifier(this._service) : super(const AssignmentState());

  /// 특정 날짜의 근무배정 목록 로드
  Future<void> loadAssignments(String workDate) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final assignments = await _service.getMyAssignments(workDate: workDate);
      state = state.copyWith(assignments: assignments, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// 근무배정 상세 로드 (체크리스트 포함)
  Future<void> loadAssignment(String id) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final assignment = await _service.getAssignment(id);
      state = state.copyWith(selected: assignment, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// 과거 근무배정 로드 (최근 30일, 페이지네이션)
  Future<void> loadPastAssignments({int page = 1}) async {
    state = state.copyWith(isPastLoading: true, error: null);
    try {
      final now = DateTime.now();
      final yesterday = now.subtract(const Duration(days: 1));
      final dateTo = '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';
      final from = yesterday.subtract(const Duration(days: 29));
      final dateFrom = '${from.year}-${from.month.toString().padLeft(2, '0')}-${from.day.toString().padLeft(2, '0')}';

      final result = await _service.getPastAssignments(
        dateTo: dateTo,
        dateFrom: dateFrom,
        page: page,
      );
      state = state.copyWith(pastResult: result, isPastLoading: false);
    } catch (e) {
      state = state.copyWith(isPastLoading: false, error: e.toString());
    }
  }

  /// 체크리스트 항목 완료/미완료 토글
  ///
  /// 사진/노트가 필요한 경우 함께 전달.
  /// 토글 후 해당 근무배정을 자동 리로드하여 최신 상태 반영.
  Future<void> toggleChecklistItem(
    String assignmentId,
    int itemIndex,
    bool isCompleted, {
    String? photoUrl,
    String? note,
  }) async {
    await _service.toggleChecklistItem(
      assignmentId,
      itemIndex,
      isCompleted,
      photoUrl: photoUrl,
      note: note,
    );
    await _reloadAssignment(assignmentId);
  }

  /// 반려된 체크리스트 항목에 재응답
  Future<void> respondToRejection(
    String assignmentId,
    int itemIndex, {
    String? responseComment,
    String? photoUrl,
  }) async {
    await _service.respondToRejection(
      assignmentId,
      itemIndex,
      responseComment: responseComment,
      photoUrl: photoUrl,
    );
    await _reloadAssignment(assignmentId);
  }

  /// 근무배정 리로드 후 목록과 상세 상태 모두 업데이트
  Future<void> _reloadAssignment(String assignmentId) async {
    final updated = await _service.getAssignment(assignmentId);
    final updatedList = state.assignments.map((a) {
      return a.id == assignmentId ? updated : a;
    }).toList();
    state = state.copyWith(selected: updated, assignments: updatedList);
  }
}
