/// 직원 의견(Voice) 상태 관리 Provider
///
/// 홈 화면에서 의견 제출 및 내 의견 목록 조회를 관리.
/// 카테고리(idea/facility/safety/hr/other)별로 의견을 분류.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/voice.dart';
import '../services/voice_service.dart';

/// 의견 상태 데이터
class VoiceState {
  final List<Voice> voices;
  final bool isLoading;
  /// 의견 제출 중 별도 로딩 상태 (UI에서 버튼 비활성화용)
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

/// 의견 Provider
final voiceProvider =
    StateNotifierProvider<VoiceNotifier, VoiceState>((ref) {
  return VoiceNotifier(ref.read(voiceServiceProvider));
});

/// 의견 상태 관리 Notifier
class VoiceNotifier extends StateNotifier<VoiceState> {
  final VoiceService _service;

  VoiceNotifier(this._service) : super(const VoiceState());

  /// 내 의견 목록 로드
  Future<void> loadVoices() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final voices = await _service.getMyVoices();
      state = state.copyWith(voices: voices, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// 새 의견 제출
  ///
  /// 성공 시 목록 맨 앞에 추가하고 true 반환.
  /// 실패 시 에러 설정하고 false 반환.
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
