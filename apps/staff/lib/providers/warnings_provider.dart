/// 경고(Warning) 상태 관리 Provider.
///
/// 미서명 카운트(My Page 배지/독촉용) + 내 active 경고 목록을 관리.
/// 상세 화면은 자체적으로 getDetail 을 호출(자동 acknowledge)하고,
/// 서명/조회 후 목록과 카운트를 리프레시한다.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/warning.dart';
import '../services/warning_service.dart';

/// 경고 상태 데이터
class WarningsState {
  final List<Warning> warnings;

  /// 미서명(employee 서명 없는) 경고 수 — 배지에 표시.
  final int unsignedCount;
  final int total;
  final bool isLoading;
  final String? error;

  const WarningsState({
    this.warnings = const [],
    this.unsignedCount = 0,
    this.total = 0,
    this.isLoading = false,
    this.error,
  });

  WarningsState copyWith({
    List<Warning>? warnings,
    int? unsignedCount,
    int? total,
    bool? isLoading,
    String? error,
  }) {
    return WarningsState(
      warnings: warnings ?? this.warnings,
      unsignedCount: unsignedCount ?? this.unsignedCount,
      total: total ?? this.total,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// 경고 Provider (앱 전역에서 접근)
final warningsProvider =
    StateNotifierProvider<WarningsNotifier, WarningsState>((ref) {
  return WarningsNotifier(ref.read(warningServiceProvider));
});

/// 경고 상태 관리 Notifier
class WarningsNotifier extends StateNotifier<WarningsState> {
  final WarningService _service;

  WarningsNotifier(this._service) : super(const WarningsState());

  /// 내 active 경고 목록 로드 + 미서명 수 파생.
  Future<void> loadWarnings() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final pageResult = await _service.list(perPage: 100);
      final unsigned = pageResult.items.where((w) => !w.isSigned).length;
      state = state.copyWith(
        warnings: pageResult.items,
        total: pageResult.total,
        unsignedCount: unsigned,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// 미서명 수만 가볍게 갱신 (My Page 배지용).
  Future<void> refreshUnsignedCount() async {
    try {
      final count = await _service.unsignedCount();
      state = state.copyWith(unsignedCount: count);
    } catch (_) {}
  }

  /// 서명 등으로 갱신된 경고를 목록에 반영하고 미서명 수를 재계산.
  void applyUpdated(Warning updated) {
    final next = state.warnings
        .map((w) => w.id == updated.id ? updated : w)
        .toList();
    state = state.copyWith(
      warnings: next,
      unsignedCount: next.where((w) => !w.isSigned).length,
    );
  }
}
