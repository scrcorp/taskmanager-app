/// 경고(Warning) 목록 화면.
///
/// 미서명 경고를 먼저, 그 다음 서명된 경고를 최신순으로 정렬해 카드로 표시.
/// 상단에 미서명 수 안내(독촉) 배너 / 전부 서명됨 안내 배너.
/// 카드 탭 → 상세 화면 (열면 서버가 자동 acknowledge).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:htm_core/htm_core.dart';

import '../../l10n/app_localizations.dart';
import '../../models/warning.dart';
import '../../providers/warnings_provider.dart';
import '../../utils/date_utils.dart';
import '../../widgets/app_header.dart';
import 'warning_status_pill.dart';

class WarningsListScreen extends ConsumerStatefulWidget {
  const WarningsListScreen({super.key});

  @override
  ConsumerState<WarningsListScreen> createState() => _WarningsListScreenState();
}

class _WarningsListScreenState extends ConsumerState<WarningsListScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(warningsProvider.notifier).loadWarnings());
  }

  /// 직원이 앱에서 서명해야 하는 경고(digital + 미서명)인지.
  /// wet 은 앱에서 할 게 없으므로 항상 false.
  bool _needsSignature(Warning w) => !w.isWet && !w.isSigned;

  /// 서명 필요(digital 미서명) 우선, 그 다음 최신(warning_date) 순으로 정렬.
  List<Warning> _sorted(List<Warning> warnings) {
    final list = [...warnings];
    list.sort((a, b) {
      final sa = _needsSignature(a) ? 0 : 1;
      final sb = _needsSignature(b) ? 0 : 1;
      if (sa != sb) return sa - sb;
      final da = a.warningDate ?? a.createdAt;
      final db = b.warningDate ?? b.createdAt;
      if (da == null && db == null) return 0;
      if (da == null) return 1;
      if (db == null) return -1;
      return db.compareTo(da);
    });
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);
    final state = ref.watch(warningsProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          AppHeader(
            title: t.warningsHeader,
            isDetail: true,
            onBack: () => context.pop(),
          ),
          Expanded(child: _buildBody(t, state)),
        ],
      ),
    );
  }

  Widget _buildBody(AppL10n t, WarningsState state) {
    if (state.isLoading && state.warnings.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: AppColors.accent));
    }

    if (state.error != null && state.warnings.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.textMuted),
              const SizedBox(height: 12),
              Text(t.warningsLoadFailed,
                  style: const TextStyle(fontSize: 15, color: AppColors.textSecondary)),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => ref.read(warningsProvider.notifier).loadWarnings(),
                child: Text(t.actionRetry),
              ),
            ],
          ),
        ),
      );
    }

    final sorted = _sorted(state.warnings);
    final unsigned = state.unsignedCount;

    return RefreshIndicator(
      color: AppColors.accent,
      onRefresh: () => ref.read(warningsProvider.notifier).loadWarnings(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (state.warnings.isNotEmpty) _buildBanner(t, unsigned),
          if (state.warnings.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 80),
              child: Center(
                child: Column(
                  children: [
                    const Icon(Icons.verified_outlined, size: 48, color: AppColors.textMuted),
                    const SizedBox(height: 12),
                    Text(t.warningsEmpty,
                        style: const TextStyle(fontSize: 15, color: AppColors.textSecondary)),
                  ],
                ),
              ),
            )
          else
            ...sorted.map((w) => Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: _WarningCard(
                    warning: w,
                    onTap: () => context.push('/my/warnings/${w.id}'),
                  ),
                )),
        ],
      ),
    );
  }

  Widget _buildBanner(AppL10n t, int unsigned) {
    if (unsigned > 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.warningBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.warning_amber_rounded, size: 18, color: AppColors.warning),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                t.warningsBannerNeedSignature(unsigned),
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text),
              ),
            ),
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.successBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline, size: 18, color: AppColors.success),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              t.warningsBannerAllSigned,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text),
            ),
          ),
        ],
      ),
    );
  }
}

/// 단일 경고 카드 — ref no(+ New 배지) · 상태 pill · 제목 · 매장 · 날짜.
class _WarningCard extends StatelessWidget {
  final Warning warning;
  final VoidCallback onTap;

  const _WarningCard({required this.warning, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);
    // 미서명 + 한 번도 열어본 적 없음(acknowledged_at == null) → "New" 점.
    // wet 경고는 직원이 앱에서 서명할 게 없어 "New(미서명)" 표시에서 제외.
    final isNew =
        !warning.isWet && !warning.isSigned && warning.acknowledgedAt == null;
    final date = warning.warningDate ?? warning.createdAt;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  warning.refNo,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMuted),
                ),
                if (isNew) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.dangerBg,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6, height: 6,
                          decoration: const BoxDecoration(
                              color: AppColors.danger, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 4),
                        Text(t.warningsNewBadge,
                            style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: AppColors.danger)),
                      ],
                    ),
                  ),
                ],
                const Spacer(),
                WarningStatusPill(warning: warning),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              warning.title,
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.text, height: 1.3),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (warning.storeName != null) ...[
                  Flexible(
                    child: Text(
                      warning.storeName!,
                      style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (date != null)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6),
                      child: Text('·', style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
                    ),
                ],
                if (date != null)
                  Text(
                    formatFixedDate(date),
                    style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
