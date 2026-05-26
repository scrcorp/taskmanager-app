/// Widget tests — 인프라 self-validation smoke test (Phase 4).
///
/// `flutter test` 실행 환경이 정상인지 확인. Phase 5 부터 실제 위젯 (Schedule
/// screen, Main numpad, 본인 확인 다이얼로그 등) 마다 widget test 추가.
///
/// [작성됨] — Phase 4
/// - 단순 MaterialApp + Text 렌더 (인프라 검증)
/// - 버튼 탭 → state 변경 (gesture/setState 흐름 검증)
///
/// [작성 필요] — Phase 5 부터
/// - AttendanceMainScreen (재설계 후 PIN numpad 렌더, identify-by-pin 호출 흐름)
/// - AttendanceScheduleScreen (오늘 출근 명단 3섹션 렌더)
/// - 본인 확인 다이얼로그 / 액션 선택 sheet

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('MaterialApp 안의 Text 가 렌더된다', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Text('hello'))),
    );
    expect(find.text('hello'), findsOneWidget);
  });

  testWidgets('버튼 탭 시 카운터 state 변경', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: _CounterPage()));

    expect(find.text('0'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();

    expect(find.text('1'), findsOneWidget);
    expect(find.text('0'), findsNothing);
  });
}

class _CounterPage extends StatefulWidget {
  const _CounterPage();

  @override
  State<_CounterPage> createState() => _CounterPageState();
}

class _CounterPageState extends State<_CounterPage> {
  int _count = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(child: Text('$_count')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => setState(() => _count++),
        child: const Icon(Icons.add),
      ),
    );
  }
}
