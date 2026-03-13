/// 스케줄 상태 관리 Provider
///
/// 월간 캘린더 + 주간 타임라인 기반. 매장 구분 없이 전체 스케줄 표시.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/schedule.dart';
import '../services/schedule_service.dart';

enum ScheduleViewMode { weekly, monthly }

class ScheduleState {
  final List<Map<String, dynamic>> stores;
  final List<WorkRole> workRoles;
  final List<ScheduleRequest> requests;
  final List<ScheduleEntry> entries;
  final List<ScheduleTemplate> templates;

  /// 현재 표시 중인 월 (1일 기준)
  final DateTime currentMonth;

  /// 현재 표시 중인 주 시작일 (일요일)
  final DateTime currentWeekStart;

  /// 뷰 모드
  final ScheduleViewMode viewMode;
  final bool isLoading;
  final String? error;

  ScheduleState({
    this.stores = const [],
    this.workRoles = const [],
    this.requests = const [],
    this.entries = const [],
    this.templates = const [],
    DateTime? currentMonth,
    DateTime? currentWeekStart,
    this.viewMode = ScheduleViewMode.weekly,
    this.isLoading = false,
    this.error,
  })  : currentMonth = currentMonth ??
            DateTime(DateTime.now().year, DateTime.now().month, 1),
        currentWeekStart = currentWeekStart ?? _thisWeekStart();

  ScheduleState copyWith({
    List<Map<String, dynamic>>? stores,
    List<WorkRole>? workRoles,
    List<ScheduleRequest>? requests,
    List<ScheduleEntry>? entries,
    List<ScheduleTemplate>? templates,
    DateTime? currentMonth,
    DateTime? currentWeekStart,
    ScheduleViewMode? viewMode,
    bool? isLoading,
    String? error,
  }) {
    return ScheduleState(
      stores: stores ?? this.stores,
      workRoles: workRoles ?? this.workRoles,
      requests: requests ?? this.requests,
      entries: entries ?? this.entries,
      templates: templates ?? this.templates,
      currentMonth: currentMonth ?? this.currentMonth,
      currentWeekStart: currentWeekStart ?? this.currentWeekStart,
      viewMode: viewMode ?? this.viewMode,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  /// 이번 주 일요일
  static DateTime _thisWeekStart() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day - (now.weekday % 7));
  }
}

final scheduleProvider =
    StateNotifierProvider<ScheduleNotifier, ScheduleState>((ref) {
  return ScheduleNotifier(ref.read(scheduleServiceProvider));
});

class ScheduleNotifier extends StateNotifier<ScheduleState> {
  final ScheduleService _service;

  ScheduleNotifier(this._service) : super(ScheduleState());

  /// 초기 로드
  Future<void> initialize() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      List<Map<String, dynamic>> stores = [];
      List<WorkRole> roles = [];
      List<ScheduleTemplate> templates = [];
      try {
        stores = await _service.getMyStores();
      } catch (_) {}
      try {
        roles = await _service.getWorkRoles();
      } catch (_) {}
      try {
        templates = await _service.getMyTemplates();
      } catch (_) {}
      state = state.copyWith(
        stores: stores,
        workRoles: roles,
        templates: templates,
      );
      await _loadData();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// 뷰 모드 전환
  void setViewMode(ScheduleViewMode mode) {
    if (state.viewMode == mode) return;
    state = state.copyWith(viewMode: mode, isLoading: true, error: null);
    _loadData();
  }

  // ── 월 네비게이션 ──

  Future<void> previousMonth() async {
    final m = state.currentMonth;
    final prev = DateTime(m.year, m.month - 1, 1);
    state = state.copyWith(currentMonth: prev, isLoading: true, error: null);
    await _loadData();
  }

  Future<void> nextMonth() async {
    final m = state.currentMonth;
    final next = DateTime(m.year, m.month + 1, 1);
    state = state.copyWith(currentMonth: next, isLoading: true, error: null);
    await _loadData();
  }

  Future<void> goToToday() async {
    final now = DateTime.now();
    final month = DateTime(now.year, now.month, 1);
    final weekStart = DateTime(now.year, now.month, now.day - (now.weekday % 7));
    state = state.copyWith(
        currentMonth: month,
        currentWeekStart: weekStart,
        isLoading: true,
        error: null);
    await _loadData();
  }

  // ── 주 네비게이션 ──

  Future<void> previousWeek() async {
    final prev = state.currentWeekStart.subtract(const Duration(days: 7));
    state = state.copyWith(currentWeekStart: prev, isLoading: true, error: null);
    // 월도 동기화
    if (prev.month != state.currentMonth.month) {
      state = state.copyWith(currentMonth: DateTime(prev.year, prev.month, 1));
    }
    await _loadData();
  }

  Future<void> nextWeek() async {
    final next = state.currentWeekStart.add(const Duration(days: 7));
    state = state.copyWith(currentWeekStart: next, isLoading: true, error: null);
    if (next.month != state.currentMonth.month) {
      state = state.copyWith(currentMonth: DateTime(next.year, next.month, 1));
    }
    await _loadData();
  }

  /// 현재 데이터 리로드
  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, error: null);
    await _loadData();
  }

  /// 템플릿 목록 리로드
  Future<void> refreshTemplates() async {
    final templates = await _service.getMyTemplates();
    state = state.copyWith(templates: templates);
  }

  /// 현재 뷰 모드에 맞는 날짜 범위로 데이터 로드
  Future<void> _loadData() async {
    try {
      final (start, end) = state.viewMode == ScheduleViewMode.weekly
          ? _weekRange(state.currentWeekStart)
          : _monthRange(state.currentMonth);
      final dateFrom = _fmt(start);
      final dateTo = _fmt(end);
      // 독립 호출: 하나 실패해도 다른 하나는 유지
      List<ScheduleRequest> reqs = [];
      List<ScheduleEntry> ents = [];
      try {
        reqs = await _service.getMyRequests(dateFrom: dateFrom, dateTo: dateTo);
      } catch (_) {}
      try {
        ents = await _service.getMyEntries(dateFrom: dateFrom, dateTo: dateTo);
      } catch (_) {}
      state = state.copyWith(
        requests: reqs,
        entries: ents,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// 주간 범위 (일~토)
  (DateTime, DateTime) _weekRange(DateTime weekStart) {
    return (weekStart, weekStart.add(const Duration(days: 6)));
  }

  /// 캘린더에 보이는 날짜 범위 (이전달 끝 일요일 ~ 다음달 초 토요일)
  (DateTime, DateTime) _monthRange(DateTime month) {
    final firstDay = DateTime(month.year, month.month, 1);
    final startOffset = firstDay.weekday % 7;
    final start = firstDay.subtract(Duration(days: startOffset));
    final lastDay = DateTime(month.year, month.month + 1, 0);
    final endOffset = 6 - (lastDay.weekday % 7);
    final end = lastDay.add(Duration(days: endOffset));
    return (start, end);
  }

  static String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
