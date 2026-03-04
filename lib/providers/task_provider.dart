/// 추가 업무(Task) 상태 관리 Provider
///
/// 나에게 배정된 추가 업무 목록 조회, 상세 조회, 완료 처리를 관리.
/// TaskListScreen과 TaskDetailScreen에서 사용.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/task.dart';
import '../services/task_service.dart';

/// 추가 업무 상태 데이터
class TaskState {
  final List<AdditionalTask> tasks;
  /// 현재 상세 보기 중인 업무
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

/// 추가 업무 Provider
final taskProvider = StateNotifierProvider<TaskNotifier, TaskState>((ref) {
  return TaskNotifier(ref.read(taskServiceProvider));
});

/// 추가 업무 상태 관리 Notifier
class TaskNotifier extends StateNotifier<TaskState> {
  final TaskService _service;

  TaskNotifier(this._service) : super(const TaskState());

  /// 나에게 배정된 업무 목록 로드 (선택적 상태 필터)
  Future<void> loadTasks({String? status}) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final tasks = await _service.getMyTasks(status: status);
      state = state.copyWith(tasks: tasks, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// 업무 상세 로드 (담당자/라벨 등 포함)
  Future<void> loadTask(String id) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final task = await _service.getTask(id);
      state = state.copyWith(selected: task, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// 업무 완료 처리 후 상태 리로드
  Future<void> completeTask(String id) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _service.completeTask(id);
      await _reloadTask(id);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// 업무 리로드 후 목록과 상세 상태 모두 업데이트
  Future<void> _reloadTask(String id) async {
    final updated = await _service.getTask(id);
    state = state.copyWith(
      selected: updated,
      tasks: state.tasks.map((t) => t.id == id ? updated : t).toList(),
      isLoading: false,
    );
  }
}
