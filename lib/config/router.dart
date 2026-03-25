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
import '../screens/auth/email_verification_screen.dart';
import '../screens/auth/find_username_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/auth/reset_password_screen.dart';
import '../screens/my/change_password_screen.dart';
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
import '../screens/inventory/store_select_screen.dart';
import '../screens/inventory/inventory_home_screen.dart';
import '../screens/inventory/inventory_list_screen.dart';
import '../screens/inventory/stock_in_screen.dart';
import '../screens/inventory/stock_out_screen.dart';
import '../screens/inventory/inventory_add_screen.dart';
import '../screens/inventory/inventory_audit_screen.dart';
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
      final user = authState.user;
      final path = state.uri.path;
      // 인증 관련 경로 (로그인, 회원가입, 회사코드 입력, 아이디 찾기, 비밀번호 재설정)
      final isAuthRoute = path == '/login' || path == '/register' || path == '/company-code'
          || path == '/find-username' || path == '/reset-password';
      final isVerifyRoute = path == '/verify-email';
      // 미인증 + 비인증 경로 접근 → 로그인으로 리다이렉트
      if (!isAuth && !isAuthRoute && !isVerifyRoute) return '/login';
      // 인증 완료 + 이메일 미인증 → 이메일 인증 화면으로 리다이렉트
      if (isAuth && user != null && !user.emailVerified && !isVerifyRoute) {
        return '/verify-email';
      }
      // 인증 완료 + 이메일 인증 완료 + 인증 경로 접근 → 홈으로 리다이렉트
      if (isAuth && user != null && user.emailVerified && (isAuthRoute || isVerifyRoute)) {
        return '/home';
      }
      return null;
    },
    routes: [
      // ── 인증 화면 (ShellRoute 바깥 = 하단 네비게이션 없음) ──
      GoRoute(path: '/company-code', builder: (_, __) => const CompanyCodeScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
      GoRoute(path: '/verify-email', builder: (_, __) => const EmailVerificationScreen()),
      GoRoute(path: '/find-username', builder: (_, __) => const FindUsernameScreen()),
      GoRoute(path: '/reset-password', builder: (_, __) => const ResetPasswordScreen()),

      // ── 메인 화면 (ShellRoute = AppShell 하단 네비게이션 포함) ──
      ShellRoute(
        builder: (_, state, child) => AppShell(child: child),
        routes: [
          GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
          GoRoute(path: '/work', builder: (_, state) => WorkScreen(
            initialTab: state.uri.queryParameters['tab'],
            scheduleId: state.uri.queryParameters['scheduleId'],
          )),
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
      GoRoute(path: '/my', builder: (_, state) => MyPageScreen(returnTo: state.extra as String?)),
      GoRoute(path: '/my/change-password', builder: (_, __) => const ChangePasswordScreen()),
      GoRoute(path: '/alerts', builder: (_, __) => const NotificationScreen()),

      // ── Inventory screens (no bottom nav) ──
      GoRoute(path: '/inventory', builder: (_, __) => const StoreSelectScreen()),
      GoRoute(
        path: '/inventory/:storeId',
        builder: (_, state) =>
            InventoryHomeScreen(storeId: state.pathParameters['storeId']!),
      ),
      GoRoute(
        path: '/inventory/:storeId/list',
        builder: (_, state) => InventoryListScreen(
          storeId: state.pathParameters['storeId']!,
          initialStatus: state.uri.queryParameters['status'],
        ),
      ),
      GoRoute(
        path: '/inventory/:storeId/stock-in',
        builder: (_, state) =>
            StockInScreen(storeId: state.pathParameters['storeId']!),
      ),
      GoRoute(
        path: '/inventory/:storeId/stock-out',
        builder: (_, state) =>
            StockOutScreen(storeId: state.pathParameters['storeId']!),
      ),
      GoRoute(
        path: '/inventory/:storeId/audit',
        builder: (_, state) =>
            InventoryAuditScreen(storeId: state.pathParameters['storeId']!),
      ),
      GoRoute(
        path: '/inventory/:storeId/add-product',
        builder: (_, state) =>
            InventoryAddScreen(storeId: state.pathParameters['storeId']!),
      ),
    ],
  );
});
