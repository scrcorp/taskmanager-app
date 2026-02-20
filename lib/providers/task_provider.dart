import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/task.dart';
import '../services/task_service.dart';

class TaskState {
  final List<AdditionalTask> tasks;
  final AdditionalTask? selected;
  final bool isLoading;
  final String? error;

  const TaskState({
    this.tasks = const [],
    this.selected,
    this.isLoading = false,
    this.error,
  });

  TaskState copyWith({
    List<AdditionalTask>? tasks,
    AdditionalTask? selected,
    bool? isLoading,
    String? error,
  }) {
    return TaskState(
      tasks: tasks ?? this.tasks,
      selected: selected ?? this.selected,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

final taskProvider = StateNotifierProvider<TaskNotifier, TaskState>((ref) {
  return TaskNotifier(ref.read(taskServiceProvider));
});

class TaskNotifier extends StateNotifier<TaskState> {
  final TaskService _service;

  TaskNotifier(this._service) : super(const TaskState());

  Future<void> loadTasks({String? status}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final tasks = await _service.getMyTasks(status: status);
      state = state.copyWith(tasks: tasks, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loadTask(String id) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final task = await _service.getTask(id);
      state = state.copyWith(selected: task, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> completeTask(String id) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _service.completeTask(id);
      // Reload the task to get updated status from server
      final updated = await _service.getTask(id);
      state = state.copyWith(
        selected: updated,
        // Also update the task in the list if present
        tasks: state.tasks.map((t) => t.id == id ? updated : t).toList(),
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}
