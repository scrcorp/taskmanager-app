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
          GoRoute(path: '/clock', builder: (_, __) => const _PlaceholderScreen(title: 'Clock In Out', icon: Icons.access_time_outlined)),
          GoRoute(path: '/schedule', builder: (_, __) => const _PlaceholderScreen(title: 'Schedule', icon: Icons.calendar_today_outlined)),
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

class _PlaceholderScreen extends StatelessWidget {
  final String title;
  final IconData icon;
  const _PlaceholderScreen({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: const Color(0xFF9CA3AF)),
          const SizedBox(height: 16),
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF1A1D2E))),
          const SizedBox(height: 8),
          const Text('Coming soon', style: TextStyle(fontSize: 14, color: Color(0xFF6B7280))),
        ],
      ),
    );
  }
}
