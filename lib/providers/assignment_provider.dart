import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/assignment.dart';
import '../models/checklist.dart';
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
    bool isCompleted,
  ) async {
    // Optimistic update on the selected assignment
    final current = state.selected;
    if (current != null && current.id == assignmentId && current.checklistSnapshot != null) {
      final updatedItems = current.checklistSnapshot!.items.map((item) {
        if (item.index == itemIndex) {
          return ChecklistItem(
            index: item.index,
            templateItemId: item.templateItemId,
            title: item.title,
            description: item.description,
            verificationType: item.verificationType,
            sortOrder: item.sortOrder,
            isCompleted: isCompleted,
            completedAt: isCompleted ? _formatLocalNow() : null,
            completedTz: isCompleted ? DateTime.now().timeZoneName : null,
          );
        }
        return item;
      }).toList();

      final updatedSnapshot = ChecklistSnapshot(
        templateId: current.checklistSnapshot!.templateId,
        templateName: current.checklistSnapshot!.templateName,
        snapshotAt: current.checklistSnapshot!.snapshotAt,
        items: updatedItems,
      );

      final updatedAssignment = Assignment(
        id: current.id,
        store: current.store,
        shift: current.shift,
        position: current.position,
        status: updatedSnapshot.isAllCompleted ? 'completed' : current.status,
        workDate: current.workDate,
        checklistSnapshot: updatedSnapshot,
        createdAt: current.createdAt,
      );

      // Update both selected and assignments list for real-time sync
      final updatedList = state.assignments.map((a) {
        return a.id == assignmentId ? updatedAssignment : a;
      }).toList();
      state = state.copyWith(selected: updatedAssignment, assignments: updatedList);
    }

    try {
      await _service.toggleChecklistItem(assignmentId, itemIndex, isCompleted);
      // Reload to get server-confirmed state
      final updated = await _service.getAssignment(assignmentId);
      final syncedList = state.assignments.map((a) {
        return a.id == assignmentId ? updated : a;
      }).toList();
      state = state.copyWith(selected: updated, assignments: syncedList);
    } catch (e) {
      // Revert on failure by reloading from server
      try {
        final reverted = await _service.getAssignment(assignmentId);
        final revertedList = state.assignments.map((a) {
          return a.id == assignmentId ? reverted : a;
        }).toList();
        state = state.copyWith(selected: reverted, assignments: revertedList, error: e.toString());
      } catch (_) {
        state = state.copyWith(error: e.toString());
      }
    }
  }

  static String _formatLocalNow() {
    final now = DateTime.now();
    final y = now.year.toString();
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    final hh = now.hour.toString().padLeft(2, '0');
    final mi = now.minute.toString().padLeft(2, '0');
    return '$y-$m-${d}T$hh:$mi';
  }
}
