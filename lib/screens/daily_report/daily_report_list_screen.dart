/// 일일 리포트 목록 화면
///
/// 내가 작성한 일일 리포트를 카드 목록으로 표시.
/// 상태 필터(All/Draft/Submitted) 지원.
/// 각 카드에 날짜, 시간대, 매장, 상태 표시.
/// FAB으로 새 리포트 생성 화면 이동. pull-to-refresh 지원.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../config/theme.dart';
import '../../providers/daily_report_provider.dart';
import '../../models/daily_report.dart';
import '../../utils/date_utils.dart';
import '../../widgets/app_header.dart';

/// 일일 리포트 목록 화면 위젯
class DailyReportListScreen extends ConsumerStatefulWidget {
  const DailyReportListScreen({super.key});
  @override
  ConsumerState<DailyReportListScreen> createState() =>
      _DailyReportListScreenState();
}

class _DailyReportListScreenState
    extends ConsumerState<DailyReportListScreen> {
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(dailyReportProvider.notifier).loadReports());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(dailyReportProvider);
    final filtered = _filter == 'all'
        ? state.reports
        : state.reports.where((r) => r.status == _filter).toList();

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          AppHeader(
            title: 'Daily Reports',
            isDetail: true,
            onBack: () => context.pop(),
          ),
          // Filter row
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                const Text('Filter: ',
                    style: TextStyle(
                        fontSize: 14, color: AppColors.textSecondary)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: DropdownButton<String>(
                    value: _filter,
                    underline: const SizedBox(),
                    isDense: true,
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('All')),
                      DropdownMenuItem(value: 'draft', child: Text('Draft')),
                      DropdownMenuItem(
                          value: 'submitted', child: Text('Submitted')),
                    ],
                    onChanged: (v) => setState(() => _filter = v ?? 'all'),
                  ),
                ),
              ],
            ),
          ),
          // Report list
          Expanded(
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                    ? const Center(
                        child: Text('No reports yet',
                            style: TextStyle(color: AppColors.textMuted)))
                    : RefreshIndicator(
                        onRefresh: () =>
                            ref.read(dailyReportProvider.notifier).loadReports(),
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 8),
                          itemCount: filtered.length,
                          itemBuilder: (_, i) =>
                              _ReportCard(report: filtered[i]),
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/daily-reports/create'),
        backgroundColor: AppColors.accent,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  final DailyReport report;
  const _ReportCard({required this.report});

  Color get _statusColor {
    switch (report.status) {
      case 'submitted':
        return AppColors.success;
      case 'reviewed':
        return AppColors.accent;
      default:
        return AppColors.warning;
    }
  }

  Color get _statusBgColor {
    switch (report.status) {
      case 'submitted':
        return AppColors.successBg;
      case 'reviewed':
        return AppColors.accentBg;
      default:
        return AppColors.warningBg;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: () => context.push('/daily-reports/${report.id}'),
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
              Row(
                children: [
                  // Date
                  Expanded(
                    child: Text(
                      formatFixedDate(report.reportDate),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.text,
                      ),
                    ),
                  ),
                  // Status badge
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _statusBgColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      report.statusLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _statusColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  // Period badge
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.bg,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      report.periodLabel,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Store name
                  if (report.storeName != null)
                    Expanded(
                      child: Text(
                        report.storeName!,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textMuted,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
