/// 변경 이력(Changelog / "What's New") 상태 관리 Provider
///
/// 공개 변경 이력 목록 조회 + slug 기반 상세 조회를 관리.
/// notice_provider 패턴(StateNotifier)을 미러링.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/changelog.dart';
import '../services/changelog_service.dart';

/// 변경 이력 목록 상태
class ChangelogState {
  final List<ChangelogListItem> items;
  final bool isLoading;
  final String? error;

  const ChangelogState({
    this.items = const [],
    this.isLoading = false,
    this.error,
  });

  ChangelogState copyWith({
    List<ChangelogListItem>? items,
    bool? isLoading,
    String? error,
  }) {
    return ChangelogState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// 변경 이력 목록 Provider
final changelogProvider =
    StateNotifierProvider<ChangelogNotifier, ChangelogState>((ref) {
  return ChangelogNotifier(ref.read(changelogServiceProvider));
});

/// 변경 이력 목록 상태 관리 Notifier
class ChangelogNotifier extends StateNotifier<ChangelogState> {
  final ChangelogService _service;

  ChangelogNotifier(this._service) : super(const ChangelogState());

  /// 변경 이력 목록 로드 (항상 첫 페이지)
  Future<void> load() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final result = await _service.getList();
      state = state.copyWith(items: result.items, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

/// slug 기반 변경 이력 상세 Provider
final changelogDetailProvider =
    FutureProvider.family<ChangelogDetail, String>((ref, slug) async {
  final service = ref.read(changelogServiceProvider);
  return service.getDetail(slug);
});
