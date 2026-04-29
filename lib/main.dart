/// TaskManager 앱의 진입점 (Entry Point)
///
/// Flutter + Riverpod 기반의 직원용 모바일 앱.
/// ProviderScope로 전역 상태관리를 초기화하고,
/// 앱 시작 시 저장된 토큰으로 인증 상태를 자동 확인한다.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'config/router.dart';
import 'config/theme.dart';
import 'providers/auth_provider.dart';
import 'utils/web_title.dart';

// 환경별 브라우저 탭 타이틀
const _appEnv = String.fromEnvironment('APP_ENV');
const appTitle = _appEnv == 'production'
    ? 'TaskManager'
    : _appEnv == 'staging'
        ? '[STG] TaskManager'
        : '[DEV] TaskManager';

void main() {
  setWebTitle(appTitle);

  // Flutter 엔진 바인딩 초기화 (runApp 전에 플러그인 사용 시 필요)
  WidgetsFlutterBinding.ensureInitialized();
  // Riverpod ProviderScope로 전체 앱을 감싸서 상태관리 활성화
  runApp(const ProviderScope(child: TaskManagerApp()));
}

/// 앱 최상위 위젯
///
/// ConsumerStatefulWidget을 사용하여 Riverpod 상태를 구독하고,
/// GoRouter 기반 라우팅과 앱 테마를 설정한다.
class TaskManagerApp extends ConsumerStatefulWidget {
  const TaskManagerApp({super.key});

  @override
  ConsumerState<TaskManagerApp> createState() => _TaskManagerAppState();
}

class _TaskManagerAppState extends ConsumerState<TaskManagerApp> {
  @override
  void initState() {
    super.initState();
    // microtask로 실행하여 build 전에 인증 상태를 확인
    // 저장된 JWT 토큰이 있으면 자동 로그인 시도
    Future.microtask(() => ref.read(authProvider.notifier).checkAuth());
  }

  @override
  Widget build(BuildContext context) {
    // GoRouter 인스턴스를 구독 (인증 상태 변경 시 리다이렉트 자동 반영)
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: appTitle,
      theme: AppTheme.light,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
