/// 강제장치 G5 — **에러 문자열 매칭 금지** (HTMA).
///
/// 왜 테스트로 막나: "표준을 문서로 선언만 하고 강제하는 장치가 없으면 지켜지지 않는다"가
/// 이 트랙의 핵심 교훈이다(`AppError` 는 2개월간 실사용 1건이었다). 그리고 대상이
/// **3곳일 때 넣는 규칙과 30곳이 된 뒤 넣는 규칙은 다른 작업**이다.
///
/// 금지하는 것 — 서버가 보낸 **문장**으로 분기하는 코드.
/// 서버 문구가 바뀌는 순간 조용히 깨지고 아무도 모른다. 분기는 `ApiError.code` 로 한다.
///
/// 예외는 [_allowed] 에 **파일 + 사유**로 적는다. 사유 없이 추가하지 마라 —
/// 허용 목록이 늘어나는 것 자체가 "서버에 코드가 없다"는 신호다.
///
/// staff 앱에도 같은 테스트가 있다(`apps/staff/test/utils/api_error_guard_test.dart`).
/// 한 파일로 합치지 않은 이유: 각 앱의 `flutter test` 가 자기 lib 를 스스로 지켜야 한다.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 에러값에서 문장을 꺼내 쓰는 수신자 이름들.
final RegExp _errorishReceiver =
    RegExp(r'(err|error|msg|message|detail|toString\(\))', caseSensitive: false);

/// `.contains('...')` / `.contains("...")`
final RegExp _containsLiteral = RegExp(r"""\.contains\(\s*(['"])(.*?)\1""");

/// 허용 목록: 파일 경로 → 사유. **서버에 대체 코드가 생기면 지운다.**
const Map<String, String> _allowed = {
  // manage 세션 종료 판정. 서버 `app/api/deps.py` 의 5개 분기가 아직 문자열 detail 이라
  // 대체할 도메인 코드가 없다. 마이그레이션 4단계(server)에서 코드가 생기면 제거.
  // TODO(error-envelope): deps.py 코드 부여 후 이 예외를 지운다.
  'lib/utils/api_error_display.dart':
      'manage 세션 판정 — server deps.py 코드 부여 대기 (마이그레이션 4단계)',

  // PIN 오류 문구 매핑. 서버가 아직 코드를 안 준다(문자열 detail).
  // TODO(error-envelope): PIN 도메인 코드화 시 제거.
  'lib/screens/attendance/attendance_main_screen.dart':
      'PIN 실패 문구 매핑 — 서버 코드 부여 대기',
};

void main() {
  test('에러 문장으로 분기하지 않는다 (허용 목록 밖)', () {
    final root = Directory('lib');
    expect(root.existsSync(), isTrue, reason: 'lib/ 를 못 찾음 — cwd 확인');

    final violations = <String>[];

    for (final entity in root.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final rel = entity.path;
      if (_allowed.containsKey(rel)) continue;

      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        final trimmed = line.trimLeft();
        // 주석은 검사하지 않는다 — 규칙을 설명하는 주석 자체가 걸리면 안 된다.
        if (trimmed.startsWith('//') || trimmed.startsWith('///')) continue;

        for (final m in _containsLiteral.allMatches(line)) {
          final literal = m.group(2) ?? '';

          // 규칙 1 — 에러/메시지 값에서 문장 조각을 찾는다.
          final receiverIsErrorish = _errorishReceiver.hasMatch(
              line.substring(0, m.start));

          // 규칙 2 — 리터럴이 사람이 쓴 문장처럼 생겼다(공백 또는 대문자 포함).
          // 길이 2 이하는 구분자(':', 'T', ' ')라 제외한다.
          final looksLikeSentence = literal.length >= 3 &&
              (literal.contains(' ') || literal != literal.toLowerCase());

          if (receiverIsErrorish || looksLikeSentence) {
            violations.add('$rel:${i + 1}  ${line.trim()}');
          }
        }
      }
    }

    expect(
      violations,
      isEmpty,
      reason: '서버 문장으로 분기하고 있다. ApiError.code 로 분기하거나, 서버에 코드가 '
          '없으면 api_error_guard_test.dart 의 허용 목록에 사유와 함께 등록하라:\n'
          '${violations.join('\n')}',
    );
  });

  test('허용 목록의 파일은 실제로 존재한다 (죽은 예외가 남지 않게)', () {
    for (final path in _allowed.keys) {
      expect(File(path).existsSync(), isTrue,
          reason: '허용 목록에 없는 파일이 남아 있다: $path');
    }
  });
}
