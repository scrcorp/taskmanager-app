import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../config/theme.dart';
import '../../providers/announcement_provider.dart';
import '../../utils/date_utils.dart';

class NoticeDetailScreen extends ConsumerStatefulWidget {
  final String id;
  const NoticeDetailScreen({super.key, required this.id});

  @override
  ConsumerState<NoticeDetailScreen> createState() =>
      _NoticeDetailScreenState();
}

class _NoticeDetailScreenState extends ConsumerState<NoticeDetailScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() =>
        ref.read(announcementProvider.notifier).loadAnnouncement(widget.id));
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(announcementProvider);
    final announcement = state.selected;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('Notice'),
      ),
      body: state.isLoading && announcement == null
          ? const Center(child: CircularProgressIndicator())
          : announcement == null
              ? Center(
                  child: Text(state.error ?? 'Notice not found',
                      style: const TextStyle(color: AppColors.textMuted)),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      Text(announcement.title,
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppColors.text)),
                      const SizedBox(height: 12),

                      // Scope + Author + Date row
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          // Scope badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: announcement.store != null
                                  ? AppColors.accentBg
                                  : AppColors.bg,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: announcement.store != null
                                    ? AppColors.accent.withValues(alpha: 0.3)
                                    : AppColors.border,
                              ),
                            ),
                            child: Text(announcement.scope,
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: announcement.store != null
                                        ? AppColors.accent
                                        : AppColors.textSecondary)),
                          ),

                          // Author
                          if (announcement.createdByName != null)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.person_outline,
                                    size: 14, color: AppColors.textMuted),
                                const SizedBox(width: 4),
                                Text(announcement.createdByName!,
                                    style: const TextStyle(
                                        fontSize: 13,
                                        color: AppColors.textSecondary)),
                              ],
                            ),

                          // Date
                          if (announcement.createdAt != null)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.calendar_today,
                                    size: 13, color: AppColors.textMuted),
                                const SizedBox(width: 4),
                                Text(
                                    formatDate(announcement.createdAt!),
                                    style: const TextStyle(
                                        fontSize: 13,
                                        color: AppColors.textSecondary)),
                              ],
                            ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Divider
                      const Divider(color: AppColors.border, height: 1),
                      const SizedBox(height: 20),

                      // Content body
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Text(announcement.content,
                            style: const TextStyle(
                                fontSize: 14,
                                height: 1.6,
                                color: AppColors.text)),
                      ),
                    ],
                  ),
                ),
    );
  }
}
