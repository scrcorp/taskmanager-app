/// 화면 밝기 provider / 네이티브 브리지 unit tests.
///
/// 검증 포인트:
///  - 저장값이 cold start 마다 복원되는가 (window brightness 는 휘발성)
///  - 드래그 중(preview)엔 저장하지 않고, 손을 뗄 때(commit)만 저장하는가
///  - 하한 아래로 못 내려가는가 (화면이 안 보이면 키오스크 복구 불가)

import 'package:attendance/providers/device_power_provider.dart';
import 'package:attendance/services/device_power_service.dart';
import 'package:attendance/utils/device_display_storage.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _deviceChannel = MethodChannel('com.tigersplus.app/device');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<MethodCall> calls;

  setUp(() {
    calls = [];
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_deviceChannel, (call) async {
      calls.add(call);
      if (call.method == 'getBrightness') return -1.0;
      return true;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_deviceChannel, null);
  });

  /// notifier 생성 직후의 비동기 _load() 가 끝날 때까지 흘려보낸다.
  Future<void> settle() => Future<void>.delayed(Duration.zero);

  group('ScreenBrightnessState', () {
    test('override 가 없으면 시스템 밝기 사용 상태', () {
      const s = ScreenBrightnessState(value: null, loaded: true);
      expect(s.usingSystem, isTrue);
      // 실제 시스템 밝기는 창 단위로 알 수 없어 슬라이더는 최대치를 보여준다.
      expect(s.sliderValue, DevicePower.maxBrightness);
    });

    test('override 가 있으면 그 값이 슬라이더 값', () {
      const s = ScreenBrightnessState(value: 0.4, loaded: true);
      expect(s.usingSystem, isFalse);
      expect(s.sliderValue, 0.4);
    });
  });

  group('DevicePower.setBrightness', () {
    test('네이티브에 clamp 된 값을 넘긴다', () async {
      await DevicePower.setBrightness(0.5);
      expect(calls.single.method, 'setBrightness');
      expect((calls.single.arguments as Map)['value'], 0.5);
    });

    test('하한 미만은 minBrightness 로 올려 보낸다 — 화면이 꺼진 듯 어두워지면 복구 불가', () async {
      await DevicePower.setBrightness(0.0);
      expect((calls.single.arguments as Map)['value'], DevicePower.minBrightness);
    });

    test('1.0 초과는 최대치로 내려 보낸다', () async {
      await DevicePower.setBrightness(2.0);
      expect((calls.single.arguments as Map)['value'], DevicePower.maxBrightness);
    });

    test('getBrightness 는 음수(override 없음)를 null 로 변환', () async {
      expect(await DevicePower.getBrightness(), isNull);
    });
  });

  group('restoreSavedBrightness', () {
    test('저장값이 있으면 창에 다시 적용한다', () async {
      SharedPreferences.setMockInitialValues({
        'attendance_screen_brightness': 0.35,
      });
      await restoreSavedBrightness();
      expect(calls.single.method, 'setBrightness');
      expect((calls.single.arguments as Map)['value'], 0.35);
    });

    test('저장값이 없으면 아무것도 하지 않는다 — 시스템 밝기를 건드리지 않음', () async {
      await restoreSavedBrightness();
      expect(calls, isEmpty);
    });
  });

  group('ScreenBrightnessNotifier', () {
    test('저장값 없이 시작 → usingSystem, loaded=true', () async {
      final notifier = ScreenBrightnessNotifier();
      addTearDown(notifier.dispose);
      await settle();
      expect(notifier.state.loaded, isTrue);
      expect(notifier.state.usingSystem, isTrue);
    });

    test('저장값이 있으면 그 값으로 시작', () async {
      SharedPreferences.setMockInitialValues({
        'attendance_screen_brightness': 0.6,
      });
      final notifier = ScreenBrightnessNotifier();
      addTearDown(notifier.dispose);
      await settle();
      expect(notifier.state.value, 0.6);
      expect(notifier.state.usingSystem, isFalse);
    });

    test('preview 는 화면에만 반영하고 저장하지 않는다', () async {
      final notifier = ScreenBrightnessNotifier();
      addTearDown(notifier.dispose);
      await settle();

      await notifier.previewBrightness(0.3);

      expect(notifier.state.value, 0.3);
      expect(calls.map((c) => c.method), contains('setBrightness'));
      expect(await DeviceDisplayStorage.getBrightness(), isNull);
    });

    test('commit 은 저장까지 한다', () async {
      final notifier = ScreenBrightnessNotifier();
      addTearDown(notifier.dispose);
      await settle();

      await notifier.commitBrightness(0.45);

      expect(notifier.state.value, 0.45);
      expect(await DeviceDisplayStorage.getBrightness(), 0.45);
    });

    test('commit 도 하한 아래로는 내려가지 않는다', () async {
      final notifier = ScreenBrightnessNotifier();
      addTearDown(notifier.dispose);
      await settle();

      await notifier.commitBrightness(0.01);

      expect(notifier.state.value, DevicePower.minBrightness);
      expect(await DeviceDisplayStorage.getBrightness(),
          DevicePower.minBrightness);
    });

    test('시스템 밝기로 되돌리면 override 해제 + 저장값 삭제', () async {
      SharedPreferences.setMockInitialValues({
        'attendance_screen_brightness': 0.6,
      });
      final notifier = ScreenBrightnessNotifier();
      addTearDown(notifier.dispose);
      await settle();

      await notifier.useSystemBrightness();

      expect(notifier.state.usingSystem, isTrue);
      expect(await DeviceDisplayStorage.getBrightness(), isNull);
      expect(calls.map((c) => c.method), contains('clearBrightness'));
    });
  });

  test('provider 로도 동일하게 동작한다', () async {
    SharedPreferences.setMockInitialValues({
      'attendance_screen_brightness': 0.25,
    });
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(screenBrightnessProvider);
    await settle();

    expect(container.read(screenBrightnessProvider).value, 0.25);
  });
}
