import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/assignment.dart';
import '../services/assignment_service.dart';

class AssignmentState {
  final List<Assignment> assignments;
  final PaginatedAssignments? pastResult;
  final Assignment? selected;
  final bool isLoading;
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

final assignmentProvider =
    StateNotifierProvider<AssignmentNotifier, AssignmentState>((ref) {
  return AssignmentNotifier(ref.read(assignmentServiceProvider));
});

class AssignmentNotifier extends StateNotifier<AssignmentState> {
  final AssignmentService _service;

  AssignmentNotifier(this._service) : super(const AssignmentState());

  Future<void> loadAssignments(String workDate) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final assignments = await _service.getMyAssignments(workDate: workDate);
      state = state.copyWith(assignments: assignments, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loadAssignment(String id) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final assignment = await _service.getAssignment(id);
      state = state.copyWith(selected: assignment, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

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

  Future<void> _reloadAssignment(String assignmentId) async {
    final updated = await _service.getAssignment(assignmentId);
    final updatedList = state.assignments.map((a) {
      return a.id == assignmentId ? updated : a;
    }).toList();
    state = state.copyWith(selected: updated, assignments: updatedList);
  }
}
