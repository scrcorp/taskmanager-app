import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/auth_provider.dart';
import '../screens/auth/company_code_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/work/work_screen.dart';
import '../screens/work/checklist_screen.dart';
import '../screens/tasks/task_list_screen.dart';
import '../screens/tasks/task_detail_screen.dart';
import '../screens/notices/notice_list_screen.dart';
import '../screens/notices/notice_detail_screen.dart';
import '../screens/my/my_page_screen.dart';
import '../screens/notifications/notification_screen.dart';
import '../widgets/app_shell.dart';

/// auth 상태 변경을 GoRouter에 알려주는 Listenable
/// Notifier that converts auth state changes to GoRouter refreshes
class _AuthNotifier extends ChangeNotifier {
  _AuthNotifier(Ref ref) {
    ref.listen(authProvider, (_, __) => notifyListeners());
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final authNotifier = _AuthNotifier(ref);

  return GoRouter(
    initialLocation: '/login',
    refreshListenable: authNotifier,
    redirect: (context, state) {
      final authState = ref.read(authProvider);
      final isAuth = authState.status == AuthStatus.authenticated;
      final path = state.uri.path;
      final isAuthRoute = path == '/login' || path == '/register' || path == '/company-code';
      if (!isAuth && !isAuthRoute) return '/login';
      if (isAuth && isAuthRoute) return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/company-code', builder: (_, __) => const CompanyCodeScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
      ShellRoute(
        builder: (_, state, child) => AppShell(child: child),
        routes: [
          GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
          GoRoute(path: '/work', builder: (_, __) => const WorkScreen()),
          GoRoute(path: '/tasks', builder: (_, __) => const TaskListScreen()),
          GoRoute(path: '/notices', builder: (_, __) => const NoticeListScreen()),
        ],
      ),
      GoRoute(path: '/work/:id', builder: (_, state) => ChecklistScreen(id: state.pathParameters['id']!)),
      GoRoute(path: '/tasks/:id', builder: (_, state) => TaskDetailScreen(id: state.pathParameters['id']!)),
      GoRoute(path: '/notices/:id', builder: (_, state) => NoticeDetailScreen(id: state.pathParameters['id']!)),
      GoRoute(path: '/my', builder: (_, __) => const MyPageScreen()),
      GoRoute(path: '/alerts', builder: (_, __) => const NotificationScreen()),
    ],
  );
});
