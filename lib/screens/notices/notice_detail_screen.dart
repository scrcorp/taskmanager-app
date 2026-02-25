import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../config/theme.dart';
import '../../providers/announcement_provider.dart';
import '../../widgets/app_header.dart';

class NoticeDetailScreen extends ConsumerStatefulWidget {
  final String id;
  const NoticeDetailScreen({super.key, required this.id});

  @override
  ConsumerState<NoticeDetailScreen> createState() => _NoticeDetailScreenState();
}

class _NoticeDetailScreenState extends ConsumerState<NoticeDetailScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(announcementProvider.notifier).loadAnnouncement(widget.id));
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(announcementProvider);
    final notice = state.selected;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          AppHeader(title: 'Notice', isDetail: true, onBack: () => context.pop()),
          if (state.isLoading && notice == null)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (notice == null)
            const Expanded(child: Center(child: Text('Notice not found')))
          else
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(notice.title, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.text)),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          if (notice.createdByName != null) ...[
                            Icon(Icons.person, size: 14, color: AppColors.textMuted),
                            const SizedBox(width: 4),
                            Text(notice.createdByName!, style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                            const SizedBox(width: 12),
                          ],
                          if (notice.createdAt != null) ...[
                            Icon(Icons.schedule, size: 14, color: AppColors.textMuted),
                            const SizedBox(width: 4),
                            Text(DateFormat('MMM d, yyyy').format(notice.createdAt!), style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                          ],
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: AppColors.accentBg, borderRadius: BorderRadius.circular(6)),
                        child: Text(notice.scope, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.accent)),
                      ),
                      const SizedBox(height: 20),
                      Divider(color: AppColors.border),
                      const SizedBox(height: 16),
                      Text(notice.content, style: TextStyle(fontSize: 15, color: AppColors.text, height: 1.6)),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
