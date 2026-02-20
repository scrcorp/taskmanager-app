# Employee Management Service — App (Flutter Web)

## Project Overview

Staff-facing mobile-first web app. Flutter Web with clean architecture pattern.

## Tech Stack

- **Framework**: Flutter 3.24+ (Web first, mobile later)
- **Language**: Dart 3.5+
- **State**: Riverpod 2 (provider + notifier)
- **HTTP**: Dio
- **Routing**: GoRouter
- **Storage**: SharedPreferences (tokens)

## Project Structure

```
app/
├── CLAUDE.md              ← You are here
├── pubspec.yaml
├── analysis_options.yaml
├── web/
│   ├── index.html
│   └── manifest.json
├── lib/
│   ├── main.dart           ← App entry, providers, theme
│   ├── app.dart            ← MaterialApp.router with GoRouter
│   │
│   ├── config/
│   │   ├── constants.dart   (API base URL, etc)
│   │   ├── theme.dart       (light theme, colors, text styles)
│   │   └── router.dart      (GoRouter routes)
│   │
│   ├── models/              ← Data models (freezed or manual)
│   │   ├── user.dart
│   │   ├── brand.dart
│   │   ├── assignment.dart
│   │   ├── checklist.dart
│   │   ├── task.dart
│   │   ├── announcement.dart
│   │   └── notification.dart
│   │
│   ├── services/            ← API calls (Dio)
│   │   ├── api_client.dart   (Dio instance + interceptors)
│   │   ├── auth_service.dart
│   │   ├── assignment_service.dart
│   │   ├── task_service.dart
│   │   ├── announcement_service.dart
│   │   └── notification_service.dart
│   │
│   ├── providers/           ← Riverpod providers
│   │   ├── auth_provider.dart
│   │   ├── assignment_provider.dart
│   │   ├── task_provider.dart
│   │   ├── announcement_provider.dart
│   │   └── notification_provider.dart
│   │
│   ├── screens/             ← Full page screens
│   │   ├── auth/
│   │   │   ├── login_screen.dart
│   │   │   └── register_screen.dart
│   │   ├── home/
│   │   │   └── home_screen.dart
│   │   ├── work/
│   │   │   ├── work_screen.dart
│   │   │   └── checklist_screen.dart
│   │   ├── tasks/
│   │   │   ├── task_list_screen.dart
│   │   │   └── task_detail_screen.dart
│   │   ├── notices/
│   │   │   ├── notice_list_screen.dart
│   │   │   └── notice_detail_screen.dart
│   │   ├── my/
│   │   │   └── my_page_screen.dart
│   │   └── notifications/
│   │       └── notification_screen.dart
│   │
│   ├── widgets/             ← Reusable widgets
│   │   ├── app_header.dart   (My icon | Title | Bell icon)
│   │   ├── bottom_nav.dart   (Home, Work, Tasks, Notices)
│   │   ├── badge_widget.dart
│   │   ├── progress_bar.dart
│   │   ├── assignment_card.dart
│   │   ├── task_card.dart
│   │   └── notice_card.dart
│   │
│   └── utils/
│       ├── token_storage.dart
│       └── date_utils.dart
│
└── test/
```

## Design System

### Color Palette (Light Theme)

```dart
class AppColors {
  static const bg = Color(0xFFF5F6FA);
  static const white = Color(0xFFFFFFFF);
  static const border = Color(0xFFE8EAF0);
  static const accent = Color(0xFF6C5CE7);
  static const accentBg = Color(0xFFF0EEFF);
  static const success = Color(0xFF00B894);
  static const successBg = Color(0xFFE6F9F4);
  static const warning = Color(0xFFF39C12);
  static const warningBg = Color(0xFFFEF5E6);
  static const danger = Color(0xFFFF6B6B);
  static const dangerBg = Color(0xFFFFEEEE);
  static const text = Color(0xFF1A1D2E);
  static const textSecondary = Color(0xFF6B7280);
  static const textMuted = Color(0xFF9CA3AF);
}
```

### Navigation Structure

**Global Header (all authenticated screens)**
```
[MyIcon]    Page Title    [🔔 Badge]
```
- Normal screens: left = My profile icon, right = notification bell
- Detail screens: left = ← back arrow, center = detail page title, right = bell

**Bottom Tab Bar (4 tabs)**
```
Home | Work | Tasks | Notices
```
- Hidden on detail screens
- Active tab: accent color

### Screen List (11 screens)

| # | Screen | Route | Phase |
|---|--------|-------|-------|
| 1 | Login | `/login` | 1 |
| 2 | Register | `/register` | 1 |
| 3 | Home | `/home` | 1-2 |
| 4 | Work (assignments by date) | `/work` | 2 |
| 5 | Checklist (tap to complete) | `/work/:id` | 2 |
| 6 | Tasks list | `/tasks` | 3 |
| 7 | Task detail + Mark Complete | `/tasks/:id` | 3 |
| 8 | Notices list | `/notices` | 3 |
| 9 | Notice detail | `/notices/:id` | 3 |
| 10 | My Page (profile + logout) | `/my` | 1 |
| 11 | Alerts (notifications) | `/alerts` | 3 |

## Key Implementation Details

### GoRouter Setup
```dart
final router = GoRouter(
  initialLocation: '/login',
  redirect: (context, state) {
    final isAuth = authNotifier.isAuthenticated;
    final isAuthRoute = state.uri.path == '/login' || state.uri.path == '/register';
    if (!isAuth && !isAuthRoute) return '/login';
    if (isAuth && isAuthRoute) return '/home';
    return null;
  },
  routes: [
    GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
    GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
    ShellRoute(
      builder: (_, __, child) => AppShell(child: child),  // header + bottom nav
      routes: [
        GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
        GoRoute(path: '/work', builder: (_, __) => const WorkScreen()),
        GoRoute(path: '/tasks', builder: (_, __) => const TaskListScreen()),
        GoRoute(path: '/notices', builder: (_, __) => const NoticeListScreen()),
      ],
    ),
    // Detail routes (no bottom nav)
    GoRoute(path: '/work/:id', builder: (_, state) => ChecklistScreen(id: state.pathParameters['id']!)),
    GoRoute(path: '/tasks/:id', builder: (_, state) => TaskDetailScreen(id: state.pathParameters['id']!)),
    GoRoute(path: '/notices/:id', builder: (_, state) => NoticeDetailScreen(id: state.pathParameters['id']!)),
    GoRoute(path: '/my', builder: (_, __) => const MyPageScreen()),
    GoRoute(path: '/alerts', builder: (_, __) => const NotificationScreen()),
  ],
);
```

### Auth Flow (App)
1. Login: POST `/app/auth/login` → store tokens
2. Register: POST `/app/auth/register` → auto login
3. Dio interceptor: attach Bearer token, handle 401 refresh
4. Staff (level 4) + Supervisor (level 3) can login

### Checklist Completion
- Tap item → PATCH `/app/my/work-assignments/:id/checklist/:item_index`
- Update local state immediately (optimistic)
- All items completed → auto status change → celebration toast

## Development Phases

### Phase 1:
1. `flutter create --platforms web app`
2. Add dependencies (riverpod, dio, go_router, shared_preferences)
3. Theme, colors, constants
4. Auth: login + register screens, token storage
5. GoRouter with auth redirect
6. AppShell (header + bottom nav)
7. Home screen (static placeholder)
8. My page (profile + logout)

### Phase 2:
9. Work screen (assignment list by date)
10. Checklist screen (tap to complete, progress bar)
11. Home screen (connect to real data)

### Phase 3:
12. Tasks list + detail + mark complete
13. Notices list + detail
14. Notifications screen (accordion)

## Commands

```bash
# Create project
flutter create --platforms web app

# Run web
flutter run -d chrome

# Build
flutter build web

# Tests
flutter test
```

## Implementation Status

| Layer | Status | Notes |
|-------|--------|-------|
| Models (7) | Complete | User, Brand, Assignment, Checklist, Task, Announcement, AppNotification |
| Services (5) | Complete | Auth, Assignment, Task, Announcement, Notification with Dio |
| Providers (5) | Complete | StateNotifierProvider pattern with optimistic updates |
| Router | Complete | Auth redirect, parameter passing to detail screens |
| Screens (11) | Complete | All Phase 1-3 screens implemented |
| Widgets (3) | Complete | AppShell, AppHeader, BottomNav |

### Provider Pattern
All providers use `StateNotifierProvider<XxxNotifier, XxxState>` with:
- Immutable state class with `copyWith`
- Loading/error state management
- Optimistic updates (checklist toggle, notification read)

### Auth Flow
- `app.dart` calls `checkAuth()` on startup
- Router watches `authProvider` for redirect
- Login/Register connect to `AuthService` via `AuthNotifier`
- JWT tokens stored in SharedPreferences

## Coding Conventions

- Use Riverpod for all state (no setState except local UI)
- Models: immutable classes with copyWith (consider freezed)
- Screens: ConsumerStatefulWidget for screens with data loading
- Widgets: small, reusable, accept callbacks
- Services: async methods returning typed data, throw on error
- Always type return values and parameters
- Use const constructors where possible
- File naming: snake_case.dart
