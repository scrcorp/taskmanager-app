/// "What's New" (변경 이력) 상세 화면
///
/// 커버 이미지, 제목, 날짜, 태그, 마크다운 본문을 표시.
/// 본문은 flutter_markdown 의 MarkdownBody 로 렌더링하며,
/// 본문 내 네트워크 이미지는 절대 URL 로 이미 resolve 되어 있다.
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:htm_core/htm_core.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/changelog_provider.dart';
import '../../widgets/app_header.dart';

/// 변경 이력 상세 화면 위젯
class ChangelogDetailScreen extends ConsumerWidget {
  final String slug;
  const ChangelogDetailScreen({super.key, required this.slug});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppL10n.of(context);
    final detailAsync = ref.watch(changelogDetailProvider(slug));

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          AppHeader(
              title: t.changelogTitle,
              isDetail: true,
              onBack: () => context.pop()),
          Expanded(
            child: detailAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (_, __) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cloud_off_outlined,
                        size: 36, color: AppColors.textMuted),
                    const SizedBox(height: 12),
                    Text(t.changelogLoadError,
                        style: const TextStyle(color: AppColors.textMuted)),
                    const SizedBox(height: 16),
                    OutlinedButton(
                      onPressed: () =>
                          ref.invalidate(changelogDetailProvider(slug)),
                      child: Text(t.changelogRetry),
                    ),
                  ],
                ),
              ),
              data: (detail) {
                final localeStr = Localizations.localeOf(context).toString();
                return SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Cover image ──
                      if (detail.coverImageUrl != null)
                        AspectRatio(
                          aspectRatio: 16 / 9,
                          child: Image.network(
                            detail.coverImageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: AppColors.bg,
                              alignment: Alignment.center,
                              child: const Icon(
                                  Icons.image_not_supported_outlined,
                                  color: AppColors.textMuted),
                            ),
                          ),
                        ),
                      // ── Header: title + meta ──
                      Container(
                        width: double.infinity,
                        color: AppColors.white,
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(detail.title,
                                style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.text)),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                const Icon(Icons.calendar_today,
                                    size: 13, color: AppColors.textMuted),
                                const SizedBox(width: 4),
                                Text(
                                  DateFormat.yMMMd(localeStr)
                                      .format(detail.publishedAt),
                                  style: const TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                            if (detail.tags.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                children: detail.tags
                                    .map((tag) => Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: AppColors.accentBg,
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                          child: Text('#$tag',
                                              style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w500,
                                                  color: AppColors.accent)),
                                        ))
                                    .toList(),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      // ── Markdown body ──
                      Container(
                        width: double.infinity,
                        color: AppColors.white,
                        padding: const EdgeInsets.all(20),
                        child: MarkdownBody(
                          data: detail.body,
                          selectable: true,
                          onTapLink: (text, href, title) async {
                            if (href == null) return;
                            final uri = Uri.tryParse(href);
                            if (uri == null) return;
                            if (await canLaunchUrl(uri)) {
                              await launchUrl(uri,
                                  mode: LaunchMode.externalApplication);
                            }
                          },
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
