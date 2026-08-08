/// 전역 업데이트 배너 — MaterialApp.builder 에 끼워 모든 라우트 위에 뜬다.
///
/// shell 은 blocker/등록/매장선택/메인만 직접 분기하고 settings·manage 화면은
/// 루트 Navigator push 로 shell 위에 덮이므로, "어느 화면에서든 다운로드
/// 상황이 보여야 한다"(이슈 1-2/1-3) 는 Navigator 바깥(builder) 에서만
/// 충족된다. builder child 에는 Material 조상이 없어 배너 자체를 Material 로
/// 감싼다. 상태는 appUpdateProvider 가 들고 있고 이 위젯은 그리기만 한다.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:htm_core/htm_core.dart';

import '../l10n/app_localizations.dart';
import '../providers/app_update_provider.dart';

/// errorKind → 원인 + 다음 행동 문구. 배너/설정/blocker 가 공유한다.
String appUpdateErrorMessage(AppL10n t, AppUpdateErrorKind? kind) {
  switch (kind) {
    case AppUpdateErrorKind.network:
      return t.attUpdateErrNetwork;
    case AppUpdateErrorKind.disk:
      return t.attUpdateErrDisk;
    case AppUpdateErrorKind.installer:
      return t.attUpdateErrInstaller;
    case AppUpdateErrorKind.unknown:
    case null:
      return t.attUpdateErrUnknown;
  }
}

/// MaterialApp.builder 용 오버레이 — child(Navigator) 위에 상단 배너를 겹친다.
class AppUpdateOverlay extends ConsumerWidget {
  final Widget? child;
  const AppUpdateOverlay({super.key, this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final update = ref.watch(appUpdateProvider);
    // downloading/installing 배너엔 누를 것이 없다 — hit-test opaque 한
    // BoxDecoration 이 아래 라우트의 터치를 삼키지 않도록 통과시킨다.
    // (ready/error 는 Install/Retry/닫기 버튼이 있어 터치를 받아야 한다.)
    final passThrough = update.phase == AppUpdatePhase.downloading ||
        update.phase == AppUpdatePhase.installing;
    return Stack(
      children: [
        if (child != null) child!,
        if (update.phase != AppUpdatePhase.idle)
          Positioned(
            // AppBar toolbar 밴드(0~kToolbarHeight) 아래에 띄운다 — 배너가
            // 어떤 라우트의 뒤로가기/AppBar 액션도 가리거나 막지 않도록.
            top: 0,
            left: 0,
            right: 0,
            child: IgnorePointer(
              ignoring: passThrough,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.only(top: kToolbarHeight),
                  // builder context 에는 Material 조상이 없다 — 배너에 직접
                  // 래핑. 단 Material 은 배너 rect 만 감싼다: 투명 Material 이
                  // toolbar 밴드까지 덮으면 InkFeatures 가 hit-test 를 삼켜
                  // 그 아래 AppBar 뒤로가기가 눌리지 않는다.
                  child: Material(
                    color: Colors.transparent,
                    child: _AppUpdateBanner(state: update),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _AppUpdateBanner extends ConsumerWidget {
  final AppUpdateState state;
  const _AppUpdateBanner({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppL10n.of(context);
    final notifier = ref.read(appUpdateProvider.notifier);
    final isError = state.phase == AppUpdatePhase.error;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isError ? AppColors.danger : AppColors.border,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: _content(t, notifier),
    );
  }

  Widget _content(AppL10n t, AppUpdateNotifier notifier) {
    switch (state.phase) {
      case AppUpdatePhase.downloading:
        final p = state.progress;
        return Row(
          children: [
            const Icon(Icons.download_rounded,
                size: 18, color: AppColors.accent),
            const SizedBox(width: 10),
            Text(
              t.attUpdateDownloading,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.text,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: LinearProgressIndicator(
                value: p,
                minHeight: 6,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              p == null ? '…' : '${(p * 100).toStringAsFixed(0)}%',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textMuted,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ],
        );
      case AppUpdatePhase.ready:
        return Row(
          children: [
            const Icon(Icons.check_circle_rounded,
                size: 18, color: AppColors.success),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                t.attUpdateReadyTitle,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
              ),
            ),
            FilledButton(
              onPressed: notifier.install,
              child: Text(t.attUpdateInstallNow),
            ),
          ],
        );
      case AppUpdatePhase.installing:
        return Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                t.attUpdateLaunchingInstaller,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
              ),
            ),
          ],
        );
      case AppUpdatePhase.error:
        return Row(
          children: [
            const Icon(Icons.error_rounded, size: 18, color: AppColors.danger),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                appUpdateErrorMessage(t, state.errorKind),
                style: const TextStyle(fontSize: 13, color: AppColors.text),
              ),
            ),
            TextButton(
              onPressed: notifier.retry,
              child: Text(t.actionRetry),
            ),
            // tooltip 금지 — 이 배너는 Navigator(Overlay) 바깥에 살아서
            // Tooltip 이 Overlay 조상을 못 찾고 크래시한다.
            IconButton(
              onPressed: notifier.dismissError,
              icon: const Icon(Icons.close_rounded, size: 18),
              color: AppColors.textMuted,
            ),
          ],
        );
      case AppUpdatePhase.idle:
        return const SizedBox.shrink();
    }
  }
}
