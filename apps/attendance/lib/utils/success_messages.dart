/// SuccessModal pure logic — Phase 5 Recovery G.
///
/// 액션별 (title, greetingTemplate) 매핑 + {name} 보간.

import '../models/attendance_action.dart';

class SuccessMessage {
  final String title;
  final String greeting;
  const SuccessMessage({required this.title, required this.greeting});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SuccessMessage && other.title == title && other.greeting == greeting;

  @override
  int get hashCode => Object.hash(title, greeting);

  @override
  String toString() => 'SuccessMessage($title, $greeting)';
}

/// 액션 + 이름 → 표시할 메시지.
/// greeting 의 '{name}' 자리표시자는 userName 으로 치환.
SuccessMessage successMessageFor(AttendanceAction action, String userName) {
  final (title, template) = switch (action) {
    AttendanceAction.clockIn => ('CLOCKED IN', 'Have a great shift, {name}!'),
    AttendanceAction.clockOut => ('CLOCKED OUT', 'Great work today, {name}!'),
    AttendanceAction.breakShortPaid => ('ON 10-MIN BREAK', 'See you in 10, {name}!'),
    AttendanceAction.breakLongUnpaid => ('MEAL BREAK', 'Enjoy your meal, {name}!'),
    AttendanceAction.breakEnd => ('BACK TO WORK', 'Welcome back, {name}!'),
  };
  return SuccessMessage(
    title: title,
    greeting: template.replaceAll('{name}', userName),
  );
}
