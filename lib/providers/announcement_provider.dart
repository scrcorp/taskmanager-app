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
}
