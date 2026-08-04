/// ManageSessionState 의 PIN 권한 플래그 파싱.
///
/// manage 세션 진입 문턱은 SV+ 인데 PIN 문턱은 GM+ 기본이라, 세션이 열렸다는
/// 사실만으로 Staff PINs 메뉴를 띄우면 SV 가 부하 직원 PIN 을 보게 된다.
/// 서버가 내려주는 플래그가 기본 false 로 안전하게 떨어지는지 확인.
import 'package:attendance/providers/attendance_manage_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ManageSessionState PIN flags', () {
    test('기본값은 둘 다 false — 모르면 숨긴다', () {
      const state = ManageSessionState();
      expect(state.canReadPins, isFalse);
      expect(state.canUpdatePins, isFalse);
    });

    test('copyWith 로 개별 설정 가능', () {
      const base = ManageSessionState(active: true);
      final updated = base.copyWith(canReadPins: true);
      expect(updated.canReadPins, isTrue);
      expect(updated.canUpdatePins, isFalse);
    });

    test('copyWith 가 기존 플래그를 유지', () {
      const base = ManageSessionState(
        active: true,
        canReadPins: true,
        canUpdatePins: true,
      );
      final updated = base.copyWith(managerName: 'GM');
      expect(updated.canReadPins, isTrue);
      expect(updated.canUpdatePins, isTrue);
    });

    test('read 만 있고 update 는 없는 조합이 표현된다', () {
      const state = ManageSessionState(
        active: true,
        canReadPins: true,
      );
      expect(state.canReadPins, isTrue);
      expect(state.canUpdatePins, isFalse);
    });
  });

  group('세션 응답 파싱 규칙', () {
    // provider 내부 파싱과 같은 규칙 — `== true` 라서 누락/null/문자열은 모두 false.
    bool parse(Object? value) => value == true;

    test('true 만 true 로 해석', () {
      expect(parse(true), isTrue);
    });

    test('필드 누락(null)은 false — 구버전 서버에 붙어도 안전', () {
      expect(parse(null), isFalse);
    });

    test('문자열 "true" 는 false — 느슨한 해석 금지', () {
      expect(parse('true'), isFalse);
    });

    test('false 는 false', () {
      expect(parse(false), isFalse);
    });
  });
}
