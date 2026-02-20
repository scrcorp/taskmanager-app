import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../config/theme.dart';
import '../../providers/announcement_provider.dart';
import '../../models/announcement.dart';
import '../../utils/date_utils.dart';

class NoticeListScreen extends ConsumerStatefulWidget {
  const NoticeListScreen({super.key});
  @override
  ConsumerState<NoticeListScreen> createState() => _NoticeListScreenState();
}

class _NoticeListScreenState extends ConsumerState<NoticeListScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
        () => ref.read(announcementProvider.notifier).loadAnnouncements());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(announcementProvider);

    return state.isLoading
        ? const Center(child: CircularProgressIndicator())
        : state.announcements.isEmpty
            ? const Center(
                child: Text('No notices',
                    style: TextStyle(color: AppColors.textMuted)))
            : RefreshIndicator(
                onRefresh: () =>
                    ref.read(announcementProvider.notifier).loadAnnouncements(),
                child: ListView.builder(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  itemCount: state.announcements.length,
                  itemBuilder: (_, i) =>
                      _NoticeCard(announcement: state.announcements[i]),
                ),
              );
  }
}

class _NoticeCard extends StatelessWidget {
  final Announcement announcement;
  const _NoticeCard({required this.announcement});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: () => context.push('/notices/${announcement.id}'),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              Text(announcement.title,
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text)),
              const SizedBox(height: 8),

              // Scope badge + author + date row
              Row(
                children: [
                  // Scope badge
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: announcement.store != null
                          ? AppColors.accentBg
                          : AppColors.bg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(announcement.scope,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: announcement.store != null
                                ? AppColors.accent
                                : AppColors.textSecondary)),
                  ),
                  const SizedBox(width: 8),

                  // Author
                  if (announcement.createdByName != null) ...[
                    Icon(Icons.person_outline,
                        size: 13, color: AppColors.textMuted),
                    const SizedBox(width: 3),
                    Text(announcement.createdByName!,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textMuted)),
                    const SizedBox(width: 8),
                  ],

                  const Spacer(),

                  // Date
                  if (announcement.createdAt != null)
                    Text(
                        formatDate(announcement.createdAt!),
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textMuted)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
