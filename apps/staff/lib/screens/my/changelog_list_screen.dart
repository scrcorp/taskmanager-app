/// "What's New" (변경 이력) 목록 화면
///
/// 공개 변경 이력(category=staff_app)을 카드 형태로 나열.
/// 각 카드에 제목, 요약, 날짜, 태그 표시. 탭하면 상세로 이동.
/// pull-to-refresh + 로딩/빈/에러 상태 지원.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:htm_core/htm_core.dart';
import '../../l10n/app_localizations.dart';
import '../../models/changelog.dart';
import '../../providers/changelog_provider.dart';
import '../../widgets/app_header.dart';

/// 변경 이력 목록 화면 위젯
class ChangelogListScreen extends ConsumerStatefulWidget {
  const ChangelogListScreen({super.key});

  @override
  ConsumerState<ChangelogListScreen> createState() =>
      _ChangelogListScreenState();
}

class _ChangelogListScreenState extends ConsumerState<ChangelogListScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(changelogProvider.notifier).load());
  }

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);
    final state = ref.watch(changelogProvider);

    Widget body;
    if (state.isLoading && state.items.isEmpty) {
      body = const Center(child: CircularProgressIndicator());
    } else if (state.error != null && state.items.isEmpty) {
      body = _ErrorView(
        message: t.changelogLoadError,
        retryLabel: t.changelogRetry,
        onRetry: () => ref.read(changelogProvider.notifier).load(),
      );
    } else if (state.items.isEmpty) {
      body = RefreshIndicator(
        onRefresh: () => ref.read(changelogProvider.notifier).load(),
        child: ListView(
          children: [
            const SizedBox(height: 120),
            Center(
              child: Text(t.changelogEmpty,
                  style: const TextStyle(color: AppColors.textMuted)),
            ),
          ],
        ),
      );
    } else {
      body = RefreshIndicator(
        onRefresh: () => ref.read(changelogProvider.notifier).load(),
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          itemCount: state.items.length,
          itemBuilder: (_, i) => _ChangelogCard(item: state.items[i]),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          AppHeader(
              title: t.changelogTitle,
              isDetail: true,
              onBack: () => context.pop()),
          Expanded(child: body),
        ],
      ),
    );
  }
}

class _ChangelogCard extends StatelessWidget {
  final ChangelogListItem item;
  const _ChangelogCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final localeStr = Localizations.localeOf(context).toString();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: () => context.push('/my/changelog/${item.slug}'),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (item.coverImageUrl != null)
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Image.network(
                    item.coverImageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: AppColors.bg,
                      alignment: Alignment.center,
                      child: const Icon(Icons.image_not_supported_outlined,
                          color: AppColors.textMuted),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(item.title,
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.text)),
                    // Summary
                    if (item.summary != null &&
                        item.summary!.trim().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(item.summary!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 13,
                              height: 1.4,
                              color: AppColors.textSecondary)),
                    ],
                    const SizedBox(height: 10),
                    // Date + tags row
                    Row(
                      children: [
                        Text(
                          DateFormat.yMMMd(localeStr).format(item.publishedAt),
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.textMuted),
                        ),
                        const Spacer(),
                        if (item.tags.isNotEmpty)
                          Flexible(
                            child: Text(
                              item.tags.take(3).map((t) => '#$t').join(' '),
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.accent),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final String retryLabel;
  final VoidCallback onRetry;
  const _ErrorView({
    required this.message,
    required this.retryLabel,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_outlined,
              size: 36, color: AppColors.textMuted),
          const SizedBox(height: 12),
          Text(message,
              style: const TextStyle(color: AppColors.textMuted)),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: onRetry,
            child: Text(retryLabel),
          ),
        ],
      ),
    );
  }
}
