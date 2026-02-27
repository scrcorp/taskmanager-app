import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/announcement.dart';
import '../services/announcement_service.dart';

class AnnouncementState {
  final List<Announcement> announcements;
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

final announcementProvider =
    StateNotifierProvider<AnnouncementNotifier, AnnouncementState>((ref) {
  return AnnouncementNotifier(ref.read(announcementServiceProvider));
});

class AnnouncementNotifier extends StateNotifier<AnnouncementState> {
  final AnnouncementService _service;

  AnnouncementNotifier(this._service) : super(const AnnouncementState());

  Future<void> loadAnnouncements() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final announcements = await _service.getAnnouncements();
      state = state.copyWith(announcements: announcements, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loadAnnouncement(String id) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final announcement = await _service.getAnnouncement(id);
      state = state.copyWith(selected: announcement, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

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
