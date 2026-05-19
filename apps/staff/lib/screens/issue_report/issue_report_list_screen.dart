/// 이슈 리포트 목록 화면.
///
/// 내가 볼 수 있는 이슈 리포트 (visibility 기반).
/// 상태 필터 (All/Open/In Progress/Closed), pull-to-refresh, FAB으로 신규 작성.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:htm_core/htm_core.dart';
import '../../models/issue_report.dart';
import '../../providers/issue_report_provider.dart';
import '../../utils/date_utils.dart';
import '../../widgets/app_header.dart';

class IssueReportListScreen extends ConsumerStatefulWidget {
  const IssueReportListScreen({super.key});

  @override
  ConsumerState<IssueReportListScreen> createState() =>
      _IssueReportListScreenState();
}

class _IssueReportListScreenState
    extends ConsumerState<IssueReportListScreen> {
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(issueReportProvider.notifier).load());
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'closed':
        return AppColors.success;
      case 'in_progress':
        return AppColors.accent;
      case 'open':
      default:
        return AppColors.warning;
    }
  }

  Color _severityColor(String? severity) {
    switch (severity) {
      case 'critical':
        return AppColors.danger;
      case 'high':
        return AppColors.warning;
      case 'medium':
        return AppColors.accent;
      case 'low':
      default:
        return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(issueReportProvider);
    final filtered = _filter == 'all'
        ? state.items
        : state.items.where((r) => r.status == _filter).toList();

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          AppHeader(
            title: 'Issues',
            isDetail: true,
            onBack: () => context.pop(),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _FilterChip(
                    label: 'All',
                    selected: _filter == 'all',
                    onTap: () => setState(() => _filter = 'all'),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Open',
                    selected: _filter == 'open',
                    onTap: () => setState(() => _filter = 'open'),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'In Progress',
                    selected: _filter == 'in_progress',
                    onTap: () => setState(() => _filter = 'in_progress'),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Closed',
                    selected: _filter == 'closed',
                    onTap: () => setState(() => _filter = 'closed'),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: state.isLoading && state.items.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: () =>
                        ref.read(issueReportProvider.notifier).load(),
                    child: filtered.isEmpty
                        ? ListView(
                            children: const [
                              SizedBox(height: 80),
                              Center(
                                child: Text(
                                  'No issues to show.',
                                  style: TextStyle(color: AppColors.textMuted),
                                ),
                              ),
                            ],
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (_, i) {
                              final r = filtered[i];
                              return _IssueCard(
                                report: r,
                                statusColor: _statusColor(r.status),
                                severityColor: _severityColor(r.severity),
                                onTap: () =>
                                    context.push('/issue-reports/${r.id}'),
                              );
                            },
                          ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.accent,
        onPressed: () => context.push('/issue-reports/create'),
        child: const Icon(Icons.add, color: AppColors.white),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.accent : AppColors.white,
          border: Border.all(
            color: selected ? AppColors.accent : AppColors.border,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? AppColors.white : AppColors.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _IssueCard extends StatelessWidget {
  final IssueReport report;
  final Color statusColor;
  final Color severityColor;
  final VoidCallback onTap;

  const _IssueCard({
    required this.report,
    required this.statusColor,
    required this.severityColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _Badge(label: report.status, color: statusColor),
                if (report.severity != null) ...[
                  const SizedBox(width: 6),
                  _Badge(label: report.severity!, color: severityColor),
                ],
                if (report.category != null) ...[
                  const SizedBox(width: 6),
                  _Badge(label: report.category!, color: AppColors.textMuted),
                ],
              ],
            ),
            const SizedBox(height: 6),
            Text(
              report.title ?? '(no title)',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.text,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (report.description != null &&
                report.description!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                report.description!,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                if (report.storeName != null) ...[
                  const Icon(Icons.place_outlined,
                      size: 12, color: AppColors.textMuted),
                  const SizedBox(width: 3),
                  Text(
                    report.storeName!,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Text(
                  formatDateTime(report.createdAt),
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
                if (report.commentCount > 0) ...[
                  const Spacer(),
                  const Icon(Icons.chat_bubble_outline,
                      size: 12, color: AppColors.textMuted),
                  const SizedBox(width: 3),
                  Text(
                    '${report.commentCount}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
