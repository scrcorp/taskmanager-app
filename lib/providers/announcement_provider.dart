/// 공지사항(Announcement) 상태 관리 Provider
///
/// 공지 목록 조회, 상세 조회, 댓글 작성, 확인(acknowledge) 토글을 관리.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/announcement.dart';
import '../services/announcement_service.dart';

/// 공지사항 상태 데이터
class AnnouncementState {
  final List<Announcement> announcements;
  /// 현재 상세 보기 중인 공지
  final Announcement? selected;
  final bool isLoading;
  final String? error;

  const AnnouncementState({
    this.announcements = const [],
    this.selected,
    this.isLoading = false,
    this.error,
  });

  AnnouncementState copyWith({
    List<Announcement>? announcements,
    Announcement? selected,
    bool? isLoading,
    String? error,
  }) {
    return AnnouncementState(
      announcements: announcements ?? this.announcements,
      selected: selected ?? this.selected,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// 공지사항 Provider (앱 전역에서 접근)
final announcementProvider =
    StateNotifierProvider<AnnouncementNotifier, AnnouncementState>((ref) {
  return AnnouncementNotifier(ref.read(announcementServiceProvider));
});

/// 공지사항 상태 관리 Notifier
class AnnouncementNotifier extends StateNotifier<AnnouncementState> {
  final AnnouncementService _service;

  AnnouncementNotifier(this._service) : super(const AnnouncementState());

  /// 공지 목록 로드 (내게 해당하는 공지만)
  Future<void> loadAnnouncements() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final announcements = await _service.getAnnouncements();
      state = state.copyWith(announcements: announcements, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// 공지 상세 로드 (댓글/확인 목록 포함)
  Future<void> loadAnnouncement(String id) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final announcement = await _service.getAnnouncement(id);
      state = state.copyWith(selected: announcement, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// 공지에 댓글 추가 (서버 응답으로 새 댓글을 로컬 상태에 추가)
  Future<void> addComment(String announcementId, {required String text}) async {
    try {
      final comment = await _service.addComment(announcementId, text);
      final current = state.selected;
      if (current != null && current.id == announcementId) {
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
  Future<void> toggleAcknowledge(String announcementId) async {
    try {
      await _service.toggleAcknowledge(announcementId);
      final current = state.selected;
      if (current != null && current.id == announcementId) {
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
