import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/voice.dart';
import '../services/voice_service.dart';

class VoiceState {
  final List<Voice> voices;
  final bool isLoading;
  final bool isSubmitting;
  final String? error;

  const VoiceState({
    this.voices = const [],
    this.isLoading = false,
    this.isSubmitting = false,
    this.error,
  });

  VoiceState copyWith({
    List<Voice>? voices,
    bool? isLoading,
    bool? isSubmitting,
    String? error,
  }) {
    return VoiceState(
      voices: voices ?? this.voices,
      isLoading: isLoading ?? this.isLoading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      error: error,
    );
  }
}

final voiceProvider =
    StateNotifierProvider<VoiceNotifier, VoiceState>((ref) {
  return VoiceNotifier(ref.read(voiceServiceProvider));
});

class VoiceNotifier extends StateNotifier<VoiceState> {
  final VoiceService _service;

  VoiceNotifier(this._service) : super(const VoiceState());

  Future<void> loadVoices() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final voices = await _service.getMyVoices();
      state = state.copyWith(voices: voices, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<bool> submitVoice({
    required String content,
    String category = 'idea',
    String priority = 'normal',
  }) async {
    state = state.copyWith(isSubmitting: true, error: null);
    try {
      final voice = await _service.createVoice(
        content: content,
        category: category,
        priority: priority,
      );
      state = state.copyWith(
        voices: [voice, ...state.voices],
        isSubmitting: false,
      );
      return true;
    } catch (e) {
      state = state.copyWith(isSubmitting: false, error: e.toString());
      return false;
    }
  }
}
