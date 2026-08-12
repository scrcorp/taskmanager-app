/// 강제장치 G3 — **3-repo 에러 코드 목록 일치**.
///
/// 코드는 server / console / app 세 저장소가 **같은 목록**을 들고 있어야 하는 계약이다.
/// 한쪽만 코드를 추가하면 다른 쪽은 "모르는 코드" 로 떨어져 문구 없이 코드만 뜨고,
/// 한쪽만 코드를 지우면 그 분기가 **조용히** 죽는다.
///
/// ## 앱 측 목록을 여기 적지 않는 이유 (2026-08-11 수정)
/// 예전에는 앱 측 집합을 이 테스트 파일 안에 **손으로 나열**했다. 그래서 대조가
/// 비대칭이었다 — `schedule_codes.dart` 에 코드를 더하거나 지워도 이 테스트는
/// 그대로 통과했고(직접 확인됨), server/console 쪽 변화만 잡혔다. 앱이 코드를
/// 지우고 서버가 그대로면 그 분기는 조용히 죽는데 CI 는 초록이었다는 뜻이다.
/// 지금은 **앱 소스에서 추출**한다. 세 저장소 모두 "파일이 정본"이 되어 대칭이 된다.
///
/// ## 저장소를 못 찾으면 skip, 파일을 못 찾으면 FAIL
/// 앱 저장소만 체크아웃한 CI 에서는 형제 저장소가 아예 없으므로 skip 이 맞다.
/// 하지만 저장소가 있는데 **대조할 파일이 없다면** 그건 환경이 아니라 계약이 깨진
/// 것이다 — 예전에는 이것도 skip 이라 존재하지 않는 경로(`app/core/error_codes.py`,
/// `console/src/lib/errorCodes.ts`)를 몇 달이고 초록으로 통과시켰다.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 한 도메인의 3-repo 짝.
class _Domain {
  final String name;

  /// 앱 측 정본 — 저장소 루트 기준 경로.
  final String dartPath;

  /// [dartPath] 에서 코드 집합을 뽑는 방법. 파일마다 정본의 모양이 다르다.
  final Set<String> Function(File) extract;

  final String serverPath; // server 저장소 루트 기준
  final String consolePath; // console 저장소 루트 기준

  /// 세 집합이 **완전히 같아야** 하는가.
  ///
  /// false 면 "앱이 가진 코드는 상대에도 있어야 한다"(app ⊆ other)만 본다.
  /// status 계열이 그렇다 — 서버 표에는 앱이 안 쓰는 status(402/405/415/426 …)와
  /// 예외 클래스 전용 코드(`DUPLICATE`)가 더 있고, 그건 문제가 아니다. 봉투가 오면
  /// 앱은 서버가 준 `code` 를 **그대로** 쓰기 때문이다(분기하지 않는다).
  /// 반대로 앱에만 있는 코드는 곧 "서버가 절대 안 보내는 코드로 분기 중"이라는 뜻이라
  /// 반드시 잡아야 한다.
  final bool exact;

  /// 서버/콘솔에 짝이 없어도 되는 **클라 전용** 코드.
  final Set<String> clientOnly;

  const _Domain({
    required this.name,
    required this.dartPath,
    required this.extract,
    required this.serverPath,
    required this.consolePath,
    this.exact = true,
    this.clientOnly = const {},
  });
}

// ── 앱 소스에서 코드 뽑기 ────────────────────────────────────

/// `const String kFoo = 'FOO';` 선언. 줄 맨 앞을 요구해 **문서 주석(`///`)은 걸리지
/// 않는다** — 주석 안의 예시 JSON 에도 코드 문자열이 들어 있어서 그걸 같이 뽑으면
/// 목록이 주석 편집에 따라 흔들린다.
final RegExp _dartConstString = RegExp(
  r'''^\s*const\s+String\s+(\w+)\s*=\s*['"]([A-Za-z][A-Za-z0-9_]*)['"]\s*;''',
  multiLine: true,
);

Map<String, String> _dartConsts(File f) => {
      for (final m in _dartConstString.allMatches(f.readAsStringSync()))
        m.group(1)!: m.group(2)!,
    };

/// 파일 안의 모든 `const String` 값 — 그 파일이 도메인의 정본일 때.
///
/// 추출 실패는 `expect` 가 아니라 예외로 알린다 — 추출은 `test()` 밖(목록을 만드는
/// 시점)에서도 불릴 수 있고, 그 자리에서 `expect` 를 쓰면 매처가 아니라
/// `OutsideTestException` 이 떠서 원인을 못 읽는다.
Set<String> _allConstValues(File f) {
  final consts = _dartConsts(f);
  if (consts.isEmpty) {
    throw StateError('${f.path} 에서 코드 상수를 하나도 못 뽑았다. '
        '선언 형태가 바뀌었다면 이 테스트의 추출기도 같이 고쳐야 한다.');
  }
  return consts.values.toSet();
}

/// `const Set<String> kName = { kA, kB, ... };` 안의 식별자를 값으로 풀어낸다.
///
/// 한 파일에 여러 집합(status / transport)이 있어서 값 전체를 쓸 수 없다.
Set<String> Function(File) _setLiteral(String name) => (File f) {
      final src = f.readAsStringSync();
      final m = RegExp('const\\s+Set<String>\\s+$name\\s*=\\s*\\{([^}]*)\\}')
          .firstMatch(src);
      if (m == null) {
        throw StateError('${f.path} 에서 `const Set<String> $name` 을 못 찾았다.');
      }
      final consts = _dartConsts(f);
      final codes = <String>{};
      for (final id
          in RegExp(r'[A-Za-z_][A-Za-z0-9_]*').allMatches(m.group(1)!)) {
        final identifier = id.group(0)!;
        final value = consts[identifier];
        // 집합 안의 식별자가 같은 파일의 const 가 아니면 추출기가 잘못 읽은 것이다.
        // 조용히 건너뛰면 목록이 줄어든 채로 통과하므로 실패시킨다.
        if (value == null) {
          throw StateError('`$identifier` 의 값을 ${f.path} 에서 못 찾았다.');
        }
        codes.add(value);
      }
      return codes;
    };

final List<_Domain> _domains = [
  _Domain(
    name: 'schedule',
    dartPath: 'apps/attendance/lib/utils/schedule_codes.dart',
    extract: _allConstValues,
    serverPath: 'app/core/schedule_codes.py',
    consolePath: 'src/lib/scheduleCodes.ts',
  ),
  // 봉투의 status 기반 일반 코드.
  //
  // 서버 정본은 `app/core/error_envelope.py` 의 status→코드 표다.
  // (`app/core/error_codes/registry.generated.json` 은 **도메인 코드** 덤프라
  //  status 계열이 들어 있지 않다. 예전 이 항목이 가리키던
  //  `app/core/error_codes.py` / `console/src/lib/errorCodes.ts` 는 아예 없는
  //  파일이라 늘 skip 이었다.)
  // transport 코드 NETWORK_* 는 클라 전용이라 대조 대상이 아니다.
  _Domain(
    name: 'api-status',
    dartPath: 'packages/htm_core/lib/src/api_error.dart',
    extract: _setLiteral('kApiStatusCodes'),
    serverPath: 'app/core/error_envelope.py',
    consolePath: 'src/lib/apiError.ts',
    exact: false,
    // 응답은 왔는데 statusCode 가 없는 병리적 경우에만 쓰는 클라 측 최후 코드.
    // 서버는 이 코드를 보낼 수 없다(status 가 있어야 응답이 나가므로).
    clientOnly: {'HTTP_ERROR'},
  ),
];

/// 따옴표 안의 UPPER_SNAKE 토큰. py/ts 양쪽에 그대로 통한다.
final RegExp _codeLiteral = RegExp(r'''["']([A-Z][A-Z0-9_]{2,})["']''');

Set<String> _codesIn(File f) =>
    _codeLiteral.allMatches(f.readAsStringSync()).map((m) => m.group(1)!).toSet();

/// 앱 저장소 루트 (`melos.yaml` 이 있는 곳). 테스트 cwd 는 패키지 디렉터리다.
Directory _appRoot() {
  var dir = Directory.current.absolute;
  while (dir.parent.path != dir.path) {
    if (File('${dir.path}/melos.yaml').existsSync()) return dir;
    dir = dir.parent;
  }
  throw StateError('melos.yaml 을 못 찾았다 — 앱 저장소 루트를 특정할 수 없다.');
}

/// 형제 저장소 루트를 찾는다.
///
/// 워크트리 레이아웃: `<루트>/{server,console,app}/.claude/worktrees/<이름>`.
/// 같은 이름의 워크트리를 우선 보고(같은 트랙의 짝이므로), 없으면 메인 체크아웃을 본다.
Directory? _repo(String repo) {
  final cwd = Directory.current.absolute.path;
  final worktree = RegExp(r'/\.claude/worktrees/([^/]+)/').firstMatch('$cwd/');
  final name = worktree?.group(1);

  var dir = Directory.current.absolute;
  while (dir.parent.path != dir.path) {
    final base = Directory('${dir.path}/$repo');
    if (base.existsSync()) {
      if (name != null) {
        final sibling = Directory('${base.path}/.claude/worktrees/$name');
        if (sibling.existsSync()) return sibling;
      }
      return base;
    }
    dir = dir.parent;
  }
  return null;
}

void main() {
  final appRoot = _appRoot();
  final server = _repo('server');
  final console = _repo('console');

  /// 앱 측 코드 — **소스에서 뽑는다.**
  ///
  /// 추출은 `test()` 안에서 처음 필요할 때 한다. 파일을 만드는 시점에 뽑으면 추출
  /// 실패가 "파일 로드 실패"로 뭉개져 어느 도메인이 왜 깨졌는지 안 보인다.
  final cache = <String, Set<String>>{};
  Set<String> appCodesOf(_Domain d) => cache.putIfAbsent(d.name, () {
        final f = File('${appRoot.path}/${d.dartPath}');
        if (!f.existsSync()) {
          throw StateError('앱 측 정본 ${d.dartPath} 가 없다. '
              '옮겼다면 이 테스트의 경로도 고쳐라.');
        }
        return d.extract(f);
      });

  /// 한쪽 저장소와의 대조. [other] 가 null 이면 그 저장소가 없는 환경이다.
  void compare(_Domain d, String label, Directory? other, String path) {
    test('$label ↔ app', () {
      if (other == null) {
        markTestSkipped('$label 저장소를 찾지 못했다 (앱만 체크아웃한 환경)');
        return;
      }
      final f = File('${other.path}/$path');
      // 저장소는 있는데 파일이 없다 = 경로가 틀렸거나 정본이 사라졌다. skip 하면
      // 아무것도 대조하지 않으면서 초록으로 남는다 — 그게 이 항목의 원래 결함이다.
      expect(f.existsSync(), isTrue,
          reason: '$label 저장소에 ${d.name} 정본 `$path` 가 없다. '
              '경로가 바뀌었으면 여기도 같이 고쳐라 (skip 은 답이 아니다).');

      final mine = appCodesOf(d);
      final theirs = _codesIn(f);
      if (d.exact) {
        expect(theirs, equals(mine),
            reason: '$label 과 앱의 ${d.name} 코드 목록이 다르다. '
                '한쪽만 바뀌면 다른 쪽 분기가 조용히 죽는다.');
      } else {
        expect(mine.difference(d.clientOnly).difference(theirs), isEmpty,
            reason: '앱에만 있는 ${d.name} 코드다 — $label 이 절대 보내지 않는 코드로 '
                '분기하고 있거나, $label 쪽에서 코드가 사라졌다.');
      }
    });
  }

  for (final d in _domains) {
    group('코드 목록 일치 — ${d.name}', () {
      compare(d, 'server', server, d.serverPath);
      compare(d, 'console', console, d.consolePath);
    });
  }

  test('도메인 간 코드 중복이 없다 (G4)', () {
    // 두 도메인이 같은 문자열을 쓰면 표시기가 어느 문구를 쓸지 알 수 없다.
    final seen = <String, String>{};
    for (final d in _domains) {
      for (final code in appCodesOf(d)) {
        expect(seen.containsKey(code), isFalse,
            reason: '코드 "$code" 가 ${seen[code]} 와 ${d.name} 에 중복 정의됐다');
        seen[code] = d.name;
      }
    }
  });
}
