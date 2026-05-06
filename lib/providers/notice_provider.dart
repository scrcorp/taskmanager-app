/// 공지사항(Notice) 상태 관리 Provider
///
/// 공지 목록 조회, 상세 조회, 댓글 작성, 확인(acknowledge) 토글을 관리.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/notice.dart';
import '../services/notice_service.dart';

/// 공지사항 상태 데이터
class NoticeState {
  final List<Notice> notices;
  /// 현재 상세 보기 중인 공지
  final Notice? selected;
  final bool isLoading;
  final String? error;

  const NoticeState({
    this.notices = const [],
    this.selected,
    this.isLoading = false,
    this.error,
  });

  NoticeState copyWith({
    List<Notice>? notices,
    Notice? selected,
    bool? isLoading,
    String? error,
  }) {
    return NoticeState(
      notices: notices ?? this.notices,
      selected: selected ?? this.selected,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// 공지사항 Provider (앱 전역에서 접근)
final noticeProvider =
    StateNotifierProvider<NoticeNotifier, NoticeState>((ref) {
  return NoticeNotifier(ref.read(noticeServiceProvider));
});

/// 공지사항 상태 관리 Notifier
class NoticeNotifier extends StateNotifier<NoticeState> {
  final NoticeService _service;

  NoticeNotifier(this._service) : super(const NoticeState());

  /// 공지 목록 로드 (내게 해당하는 공지만)
  Future<void> loadNotices() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final notices = await _service.getNotices();
      state = state.copyWith(notices: notices, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// 공지 상세 로드 (댓글/확인 목록 포함)
  Future<void> loadNotice(String id) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final notice = await _service.getNotice(id);
      state = state.copyWith(selected: notice, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// 공지에 댓글 추가 (서버 응답으로 새 댓글을 로컬 상태에 추가)
  Future<void> addComment(String noticeId, {required String text}) async {
    try {
      final comment = await _service.addComment(noticeId, text);
      final current = state.selected;
      if (current != null && current.id == noticeId) {
        state = state.copyWith(
          selected: current.copyWith(
            comments: [...current.comments, comment],
          ),
        );
      }
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  /// 공지 확인(읽음) 상태 토글
  Future<void> toggleAcknowledge(String noticeId) async {
    try {
      await _service.toggleAcknowledge(noticeId);
      final current = state.selected;
      if (current != null && current.id == noticeId) {
        state = state.copyWith(
          selected: current.copyWith(
            isAcknowledged: !current.isAcknowledged,
          ),
        );
      }
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }
}
