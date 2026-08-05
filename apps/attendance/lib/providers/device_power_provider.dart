/// 배터리 상태 / 화면 밝기 provider.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/battery_status.dart';
import '../services/device_power_service.dart';
import '../utils/device_display_storage.dart';

/// 배터리 상태 스트림. 헤더의 배터리 칩이 구독한다.
/// 구독자가 없으면 네이티브 receiver 도 해제되므로 유휴 비용이 없다.
final batteryStatusProvider = StreamProvider<BatteryStatus>(
  (ref) => DevicePower.batteryStream(),
);

/// 앱 시작 시 저장된 밝기를 창에 다시 적용한다.
///
/// window brightness 는 프로세스가 죽으면 사라지므로 cold start 마다 필요하다.
/// 저장값이 없으면 아무것도 하지 않고 시스템 밝기를 그대로 쓴다.
Future<void> restoreSavedBrightness() async {
  final saved = await DeviceDisplayStorage.getBrightness();
  if (saved == null) return;
  await DevicePower.setBrightness(saved);
}

/// 화면 밝기 설정 상태.
class ScreenBrightnessState {
  /// 0.0~1.0. null 이면 override 없이 시스템 밝기를 따르는 중.
  final double? value;

  /// 저장소에서 초기값을 읽어왔는지. false 동안 슬라이더는 비활성.
  final bool loaded;

  const ScreenBrightnessState({this.value, this.loaded = false});

  /// 슬라이더에 표시할 값 — override 가 없으면 최대치를 기준으로 보여준다
  /// (시스템 밝기 실제값은 창 단위로 알 수 없기 때문).
  double get sliderValue => value ?? DevicePower.maxBrightness;

  bool get usingSystem => value == null;
}

class ScreenBrightnessNotifier extends StateNotifier<ScreenBrightnessState> {
  ScreenBrightnessNotifier() : super(const ScreenBrightnessState()) {
    _load();
  }

  Future<void> _load() async {
    final saved = await DeviceDisplayStorage.getBrightness();
    if (!mounted) return;
    state = ScreenBrightnessState(value: saved, loaded: true);
  }

  /// 슬라이더를 끄는 중 — 화면에는 즉시 반영하되 저장은 하지 않는다.
  /// (드래그 한 번에 SharedPreferences 를 수십 번 쓰지 않기 위함)
  Future<void> previewBrightness(double value) async {
    final clamped = _clamp(value);
    state = ScreenBrightnessState(value: clamped, loaded: true);
    await DevicePower.setBrightness(clamped);
  }

  /// 슬라이더에서 손을 뗀 시점 — 최종값을 기기에 저장한다.
  Future<void> commitBrightness(double value) async {
    final clamped = _clamp(value);
    state = ScreenBrightnessState(value: clamped, loaded: true);
    await DevicePower.setBrightness(clamped);
    await DeviceDisplayStorage.setBrightness(clamped);
  }

  double _clamp(double value) => value.clamp(
        DevicePower.minBrightness,
        DevicePower.maxBrightness,
      );

  /// 시스템 밝기로 되돌리기.
  Future<void> useSystemBrightness() async {
    state = const ScreenBrightnessState(value: null, loaded: true);
    await DevicePower.clearBrightness();
    await DeviceDisplayStorage.clearBrightness();
  }
}

final screenBrightnessProvider =
    StateNotifierProvider<ScreenBrightnessNotifier, ScreenBrightnessState>(
  (ref) => ScreenBrightnessNotifier(),
);
