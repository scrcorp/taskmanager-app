/// 내 스케줄(MySchedule) 상태 관리 Provider
///
/// 오늘의 스케줄, 과거 스케줄, 체크리스트 항목 완료/반려 응답을 관리.
/// WorkScreen과 ChecklistScreen에서 사용 (기존 assignmentProvider 대체).
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/my_schedule.dart';
import '../services/schedule_service.dart';

/// 내 스케줄 상태 데이터
class MyScheduleState {
  /// 오늘의 스케줄 목록
  final List<MySchedule> schedules;
  /// 과거 스케줄 (페이지네이션 결과)
  final PaginatedMySchedules? pastResult;
  /// 현재 상세 보기 중인 스케줄
  final MySchedule? selected;
  final bool isLoading;
  /// 과거 스케줄 별도 로딩 상태
  final bool isPastLoading;
  final String? error;

  const MyScheduleState({
    this.schedules = const [],
    this.pastResult,
    this.selected,
    this.isLoading = false,
    this.isPastLoading = false,
    this.error,
  });

  /// 과거 스케줄 항목 목록 (편의 접근자)
  List<MySchedule> get pastSchedules => pastResult?.items ?? [];

  MyScheduleState copyWith({
    List<MySchedule>? schedules,
    PaginatedMySchedules? pastResult,
    MySchedule? selected,
    bool? isLoading,
    bool? isPastLoading,
    String? error,
  }) {
    return MyScheduleState(
      schedules: schedules ?? this.schedules,
      pastResult: pastResult ?? this.pastResult,
      selected: selected ?? this.selected,
      isLoading: isLoading ?? this.isLoading,
      isPastLoading: isPastLoading ?? this.isPastLoading,
      error: error,
    );
  }
}

/// 내 스케줄 Provider
final myScheduleProvider =
    StateNotifierProvider<MyScheduleNotifier, MyScheduleState>((ref) {
  return MyScheduleNotifier(ref.read(scheduleServiceProvider));
});

/// 내 스케줄 상태 관리 Notifier
class MyScheduleNotifier extends StateNotifier<MyScheduleState> {
  final ScheduleService _service;

  MyScheduleNotifier(this._service) : super(const MyScheduleState());

  /// 특정 날짜의 스케줄 목록 로드
  Future<void> loadSchedules(String workDate) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final schedules = await _service.getMySchedules(workDate: workDate);
      state = state.copyWith(schedules: schedules, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// 스케줄 상세 로드 (체크리스트 포함)
  Future<void> loadSchedule(String id) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final schedule = await _service.getMyScheduleDetail(id);
      state = state.copyWith(selected: schedule, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// 과거 스케줄 로드 (최근 30일, 페이지네이션)
  Future<void> loadPastSchedules({int page = 1}) async {
    state = state.copyWith(isPastLoading: true, error: null);
    try {
      final now = DateTime.now();
      final yesterday = now.subtract(const Duration(days: 1));
      final dateTo = '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';
      final from = yesterday.subtract(const Duration(days: 29));
      final dateFrom = '${from.year}-${from.month.toString().padLeft(2, '0')}-${from.day.toString().padLeft(2, '0')}';

      final result = await _service.getPastMySchedules(
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
  Future<void> toggleChecklistItem(
    String scheduleId,
    int itemIndex,
    bool isCompleted, {
    String? photoUrl,
    String? note,
  }) async {
    await _service.toggleChecklistItem(
      scheduleId,
      itemIndex,
      isCompleted,
      photoUrl: photoUrl,
      note: note,
    );
    await _reloadSchedule(scheduleId);
  }

  /// 반려된 체크리스트 항목에 재응답
  Future<void> respondToRejection(
    String scheduleId,
    int itemIndex, {
    String? responseComment,
    String? photoUrl,
  }) async {
    await _service.respondToRejection(
      scheduleId,
      itemIndex,
      responseComment: responseComment,
      photoUrl: photoUrl,
    );
    await _reloadSchedule(scheduleId);
  }

  /// 스케줄 리로드 후 목록과 상세 상태 모두 업데이트
  Future<void> _reloadSchedule(String scheduleId) async {
    final updated = await _service.getMyScheduleDetail(scheduleId);
    final updatedList = state.schedules.map((s) {
      return s.id == scheduleId ? updated : s;
    }).toList();
    state = state.copyWith(selected: updated, schedules: updatedList);
  }
}
