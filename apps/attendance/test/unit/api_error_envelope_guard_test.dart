/// 강제장치 G5-b — **에러 봉투를 직접 파헤치지 않는다** (HTMA).
///
/// 승인된 입구는 `extractApiError` / `parseApiError` 하나뿐이다.
/// 그런데 `e.response?.data` 를 직접 읽고 `['detail']` 을 꺼내 쓰면,
/// 봉투의 `error.code` 대신 **서버 문구(detail 문자열)** 에 다시 의존하게 된다.
/// 서버가 문구를 바꾸는 순간 조용히 오작동한다 — 이 트랙이 없애려던 바로 그 병이다.
///
/// 그래서 우회 지점을 **세어두고, 늘어나면 실패**시킨다.
/// 문서·규칙으로는 못 막는다(읽고 무시할 수 있다). 세는 것만이 물리적으로 막는다.
///
/// 기준치는 **측정값**이고 내려가는 방향으로만 갱신한다(측정: 2026-08-11).
/// 총계가 아니라 **파일별 개수**로 잡는 이유: 총계만 세면 한 곳을 고치고 다른 곳에
/// 새로 만들어도 통과한다.
///
/// staff 앱에도 같은 테스트가 있다(`apps/staff/test/utils/api_error_envelope_guard_test.dart`).
/// 한 파일로 합치지 않은 이유는 문자열 가드와 같다 —
/// 각 앱의 `flutter test` 가 자기 lib 를 스스로 지켜야 한다.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 우회 패턴 1 — HTTP 에러 객체에서 **원문 바디**를 직접 꺼낸다.
/// `.response.data` / `.response?.data` / `.response!.data`.
/// 앞에 `.` 을 요구하는 이유: 성공 응답을 담은 지역변수 `response.data` 는
/// 봉투 우회가 아니다. 에러에서 꺼내는 `e.response?.data` 형태만 잡는다.
final RegExp _rawResponseBody = RegExp(r'\.\s*response\s*[?!]?\s*\.\s*data\b');

/// 우회 패턴 2 — 봉투 대신 레거시 미러 키를 직접 첨자한다. `['detail']` / `["detail"]`.
final RegExp _detailSubscript = RegExp(r'''\[\s*(['"])detail\1\s*\]''');

/// 파서 구현체 자신 — 여기서는 원문 바디를 읽는 게 **일**이다.
///
/// `api_error_display.dart`(승인된 입구 `extractApiError` 가 사는 곳)는 **제외하지 않는다**.
/// 지금 위반이 0이고, 여기가 뚫리면 "입구 안에서 우회"가 되어 가드 전체가 무의미해진다.
/// 정말 필요해지면 다른 파일과 똑같이 허용 목록에 등재하면 된다.
bool _isParser(String path) => RegExp(r'(^|/)api_error\.dart$').hasMatch(path);

/// 허용 목록: 파일 경로 → (현재 위반 줄 수, 사유).
///
/// 파일만 등재하면 그 파일이 무한 통로가 된다. 그래서 **개수까지** 고정한다.
/// 개수는 줄어들 수만 있다 — 고쳤으면 이 숫자를 낮춰라. 늘리는 수정은 리뷰 대상이다.
const Map<String, ({int count, String why})> _allowed = {
  'lib/providers/attendance_dashboard_provider.dart': (
    count: 3,
    why: '대시보드 로드 실패 detail 파싱. 봉투 이전 코드 — extractApiError 로 이관 대기',
  ),
  'lib/providers/attendance_manage_provider.dart': (
    count: 3,
    why: 'manage 액션 실패 detail 파싱. 봉투 이전 코드 — extractApiError 로 이관 대기',
  ),
  'lib/providers/attendance_device_provider.dart': (
    count: 5,
    why: '기기 등록/해제 실패 detail 파싱(2개 헬퍼). 봉투 이전 코드 — 이관 대기',
  ),
  'lib/utils/schedule_codes.dart': (
    count: 2,
    why: 'schedule 코드 계약이 detail.code 로 3-repo 배포되어 있다. 봉투로 옮기려면 서버·콘솔 동시 변경 필요',
  ),
  'lib/screens/attendance/attendance_manage_staff_pins_screen.dart': (
    count: 2,
    why: 'PIN 충돌(409) detail 추출. pin_conflict 계약이 detail 평탄 구조로 3클라 공유 중',
  ),
};

/// 주석을 지우고 문자열 리터럴의 **내용을 비운** 소스. **오탐 방지의 핵심.**
///
/// 정규식으로 훑기 때문에 두 가지를 반드시 걷어내야 한다.
///  1. 주석 — 이 규칙을 설명하는 주석 자체가 위반으로 잡히면 안 된다
///     (실제로 staff `daily_report_detail_screen.dart` 에 그런 주석이 있다).
///  2. 문자열 — 로그/설명 문구에 `e.response?.data` 를 적었다고 위반은 아니다.
///
/// 다만 문자열을 통째로 지우면 `['detail']` 의 `detail` 까지 사라져 패턴이 죽는다.
/// 그래서 **내용이 정확히 `detail` 인 리터럴만 남기고** 나머지는 내용을 비운다.
/// 이러면 코드의 `data['detail']` 은 그대로 잡히고,
/// 문자열 안에 적힌 `data['detail']` 은 바깥 리터럴이 통째로 비워져 잡히지 않는다.
List<String> _codeOnly(List<String> lines) {
  final out = <String>[];
  var inBlock = false;
  String? delim; // 열려 있는 문자열 구분자 (삼중/단일 따옴표)
  var lit = StringBuffer(); // 현재 문자열 내용

  String emit(String content) => content == 'detail' ? "'detail'" : "''";

  for (final line in lines) {
    final buf = StringBuffer();
    var i = 0;
    while (i < line.length) {
      if (inBlock) {
        if (line.startsWith('*/', i)) {
          inBlock = false;
          i += 2;
        } else {
          i++;
        }
        continue;
      }
      if (delim != null) {
        if (line.startsWith(delim, i)) {
          buf.write(emit(lit.toString()));
          lit = StringBuffer();
          i += delim.length;
          delim = null;
          continue;
        }
        // 이스케이프는 두 글자를 통째로 넘긴다 — `\'` 가 리터럴을 닫는 것으로 오인되면 안 된다.
        if (line[i] == r'\' && i + 1 < line.length) {
          lit.write(line.substring(i, i + 2));
          i += 2;
          continue;
        }
        lit.write(line[i]);
        i++;
        continue;
      }
      if (line.startsWith("'''", i) || line.startsWith('"""', i)) {
        delim = line.substring(i, i + 3);
        i += 3;
        continue;
      }
      if (line[i] == "'" || line[i] == '"') {
        delim = line[i];
        i++;
        continue;
      }
      if (line.startsWith('//', i)) break; // 라인 주석 — 이후는 버린다
      if (line.startsWith('/*', i)) {
        inBlock = true;
        i += 2;
        continue;
      }
      buf.write(line[i]);
      i++;
    }
    // 한 줄짜리 리터럴이 닫히지 않은 채 줄이 끝나면(문법상 불가) 여기서 닫는다.
    // 삼중 따옴표만 다음 줄로 이어진다.
    if (delim != null && delim.length == 1) {
      buf.write(emit(lit.toString()));
      lit = StringBuffer();
      delim = null;
    }
    out.add(buf.toString());
  }
  return out;
}

/// 파일별 위반 줄 목록. 한 줄에 패턴이 두 번 나와도 1로 센다(개수 안정성).
Map<String, List<String>> _scan() {
  final found = <String, List<String>>{};
  final root = Directory('lib');
  if (!root.existsSync()) return found;

  for (final entity in root.listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    final rel = entity.path;
    if (_isParser(rel)) continue; // 파서 구현체는 대상 아님

    final source = _codeOnly(entity.readAsLinesSync());
    final original = entity.readAsLinesSync();
    for (var i = 0; i < source.length; i++) {
      final code = source[i];
      if (_rawResponseBody.hasMatch(code) || _detailSubscript.hasMatch(code)) {
        found.putIfAbsent(rel, () => []).add('$rel:${i + 1}  ${original[i].trim()}');
      }
    }
  }
  return found;
}

const _howToFix = '''
봉투를 직접 파헤치지 마라. `extractApiError(e)` / `parseApiError(...)` 로 ApiError 를 얻고
`error.code` 로 분기하라 (`detail` 문자열/키에 의존하면 서버 문구 변경에 조용히 깨진다).
정말 예외라면(3-repo 계약이 이미 detail 평탄 구조로 배포된 경우 등)
apps/attendance/test/unit/api_error_envelope_guard_test.dart 의 _allowed 에
파일 경로 + 현재 줄 수 + 사유를 적어 등재하라.''';

void main() {
  test('허용 목록 밖에서 봉투를 직접 파헤치지 않는다', () {
    final found = _scan();
    expect(Directory('lib').existsSync(), isTrue, reason: 'lib/ 를 못 찾음 — cwd 확인');

    final newFiles = <String>[];
    for (final entry in found.entries) {
      if (_allowed.containsKey(entry.key)) continue;
      newFiles.addAll(entry.value);
    }
    expect(
      newFiles,
      isEmpty,
      reason: '허용 목록에 없는 파일에서 원문 응답 바디/`detail` 첨자를 직접 읽는다:\n'
          '${newFiles.join('\n')}\n$_howToFix',
    );
  });

  test('허용 목록 파일의 위반 개수가 늘지 않는다', () {
    final found = _scan();
    final grown = <String>[];
    for (final entry in _allowed.entries) {
      final actual = found[entry.key]?.length ?? 0;
      if (actual > entry.value.count) {
        grown.add('${entry.key}: ${entry.value.count} → $actual\n'
            '${(found[entry.key] ?? []).join('\n')}');
      }
    }
    expect(
      grown,
      isEmpty,
      reason: '허용 목록 파일에서 우회 지점이 늘었다(기준치는 내려가는 방향으로만 갱신한다):\n'
          '${grown.join('\n')}\n$_howToFix',
    );
  });

  test('허용 목록이 실측과 어긋나지 않는다 (죽은 예외·과한 여유 금지)', () {
    final found = _scan();
    final stale = <String>[];
    for (final entry in _allowed.entries) {
      if (!File(entry.key).existsSync()) {
        stale.add('${entry.key}: 파일이 없다 — 허용 목록에서 지워라');
        continue;
      }
      final actual = found[entry.key]?.length ?? 0;
      if (actual < entry.value.count) {
        stale.add('${entry.key}: 실제 $actual 개인데 기준치가 ${entry.value.count} 이다 — '
            '기준치를 $actual 로 낮춰라(줄어든 만큼 잠가야 되돌아오지 않는다)');
      }
    }
    expect(stale, isEmpty, reason: stale.join('\n'));
  });
}
