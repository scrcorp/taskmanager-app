import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/assignment.dart';
import '../services/assignment_service.dart';

class AssignmentState {
  final List<Assignment> assignments;
  final Assignment? selected;
  final bool isLoading;
  final String? error;

  const AssignmentState({
    this.assignments = const [],
    this.selected,
    this.isLoading = false,
    this.error,
  });

  AssignmentState copyWith({
    List<Assignment>? assignments,
    Assignment? selected,
    bool? isLoading,
    String? error,
  }) {
    return AssignmentState(
      assignments: assignments ?? this.assignments,
      selected: selected ?? this.selected,
      isLoading: isLoading ?? this.isLoading,
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

  Future<void> _reloadAssignment(String assignmentId) async {
    final updated = await _service.getAssignment(assignmentId);
    final updatedList = state.assignments.map((a) {
      return a.id == assignmentId ? updated : a;
    }).toList();
    state = state.copyWith(selected: updated, assignments: updatedList);
  }
}
