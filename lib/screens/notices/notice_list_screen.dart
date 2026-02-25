import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../config/theme.dart';
import '../../providers/announcement_provider.dart';

class NoticeListScreen extends ConsumerStatefulWidget {
  const NoticeListScreen({super.key});

  @override
  ConsumerState<NoticeListScreen> createState() => _NoticeListScreenState();
}

class _NoticeListScreenState extends ConsumerState<NoticeListScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(announcementProvider.notifier).loadAnnouncements());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(announcementProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: state.isLoading && state.announcements.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : state.announcements.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.campaign_outlined, size: 48, color: AppColors.textMuted),
                      const SizedBox(height: 12),
                      Text('No announcements', style: TextStyle(fontSize: 15, color: AppColors.textMuted)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () => ref.read(announcementProvider.notifier).loadAnnouncements(),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: state.announcements.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      final notice = state.announcements[i];
                      return GestureDetector(
                        onTap: () => context.push('/notices/${notice.id}'),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(color: AppColors.accentBg, borderRadius: BorderRadius.circular(10)),
                                child: Icon(Icons.campaign, size: 20, color: AppColors.accent),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(notice.title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.text), maxLines: 1, overflow: TextOverflow.ellipsis),
                                    const SizedBox(height: 3),
                                    Text(
                                      '${notice.createdByName ?? ''}${notice.createdAt != null ? ' · ${DateFormat('MMM d').format(notice.createdAt!)}' : ''} · ${notice.scope}',
                                      style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(Icons.chevron_right, size: 20, color: AppColors.textMuted),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
