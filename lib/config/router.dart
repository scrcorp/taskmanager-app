/// GoRouter 기반 라우팅 설정
///
/// 인증 상태에 따른 자동 리다이렉트를 처리하고,
/// 앱의 모든 화면 경로를 정의한다.
/// - 미인증 시 → /login으로 리다이렉트
/// - 인증 완료 후 인증 화면 접근 → /home으로 리다이렉트
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/auth_provider.dart';
import '../screens/auth/company_code_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/clock/clock_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/my/my_page_screen.dart';
import '../screens/notices/notice_detail_screen.dart';
import '../screens/notices/notice_list_screen.dart';
import '../screens/notifications/notification_screen.dart';
import '../screens/ojt/ojt_screen.dart';
import '../screens/schedule/schedule_screen.dart';
import '../screens/daily_report/daily_report_detail_screen.dart';
import '../screens/daily_report/daily_report_list_screen.dart';
import '../screens/tasks/task_detail_screen.dart';
import '../screens/tasks/task_list_screen.dart';
import '../screens/work/checklist_screen.dart';
import '../screens/work/work_screen.dart';
import '../widgets/app_shell.dart';

/// 인증 상태 변경을 GoRouter에 전달하기 위한 ChangeNotifier
///
/// authProvider의 상태가 변경되면 notifyListeners()를 호출하여
/// GoRouter가 redirect 로직을 재실행하도록 트리거한다.
class _AuthNotifier extends ChangeNotifier {
  _AuthNotifier(Ref ref) {
    ref.listen(authProvider, (_, __) => notifyListeners());
  }
}

/// GoRouter 인스턴스를 제공하는 Riverpod Provider
///
/// 앱 전체의 라우팅을 관리하며, 인증 상태에 따라
/// 적절한 화면으로 리다이렉트한다.
final routerProvider = Provider<GoRouter>((ref) {
  final authNotifier = _AuthNotifier(ref);

  return GoRouter(
    initialLocation: '/login',
    // 인증 상태 변경 시 리다이렉트 로직 재실행
    refreshListenable: authNotifier,
    redirect: (context, state) {
      final authState = ref.read(authProvider);
      final isAuth = authState.status == AuthStatus.authenticated;
      final path = state.uri.path;
      // 인증 관련 경로 (로그인, 회원가입, 회사코드 입력)
      final isAuthRoute = path == '/login' || path == '/register' || path == '/company-code';
      // 미인증 + 비인증 경로 접근 → 로그인으로 리다이렉트
      if (!isAuth && !isAuthRoute) return '/login';
      // 인증 완료 + 인증 경로 접근 → 홈으로 리다이렉트
      if (isAuth && isAuthRoute) return '/home';
      return null;
    },
    routes: [
      // ── 인증 화면 (ShellRoute 바깥 = 하단 네비게이션 없음) ──
      GoRoute(path: '/company-code', builder: (_, __) => const CompanyCodeScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),

      // ── 메인 화면 (ShellRoute = AppShell 하단 네비게이션 포함) ──
      ShellRoute(
        builder: (_, state, child) => AppShell(child: child),
        routes: [
          GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
          GoRoute(path: '/work', builder: (_, __) => const WorkScreen()),
          GoRoute(path: '/clock', builder: (_, __) => const ClockScreen()),
          GoRoute(path: '/schedule', builder: (_, __) => const ScheduleScreen()),
        ],
      ),

      // ── 독립 화면 (ShellRoute 바깥 = 전체 화면) ──
      GoRoute(path: '/ojt', builder: (_, __) => const OjtScreen()),
      GoRoute(path: '/tasks', builder: (_, __) => const TaskListScreen()),
      GoRoute(path: '/tasks/:id', builder: (_, state) => TaskDetailScreen(id: state.pathParameters['id']!)),
      GoRoute(path: '/notices', builder: (_, __) => const NoticeListScreen()),
      GoRoute(path: '/notices/:id', builder: (_, state) => NoticeDetailScreen(id: state.pathParameters['id']!)),
      GoRoute(path: '/work/:id', builder: (_, state) => ChecklistScreen(id: state.pathParameters['id']!)),
      GoRoute(path: '/daily-reports', builder: (_, __) => const DailyReportListScreen()),
      GoRoute(path: '/daily-reports/create', builder: (_, __) => const DailyReportDetailScreen()),
      GoRoute(path: '/daily-reports/:id', builder: (_, state) => DailyReportDetailScreen(id: state.pathParameters['id']!)),
      GoRoute(path: '/my', builder: (_, __) => const MyPageScreen()),
      GoRoute(path: '/alerts', builder: (_, __) => const NotificationScreen()),
    ],
  );
});
