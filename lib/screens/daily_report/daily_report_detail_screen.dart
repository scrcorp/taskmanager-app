/// 일일 리포트 상세 화면
///
/// 리포트 헤더(날짜, 시간대, 매장, 상태) + 섹션 내용 표시.
/// Draft 상태이고 본인 리포트인 경우:
///   - 인라인 편집 모드 (텍스트필드로 전환)
///   - Save / Submit 버튼
/// 하단에 댓글 목록 (읽기 전용).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../config/theme.dart';
import '../../models/daily_report.dart';
import '../../providers/auth_provider.dart';
import '../../providers/daily_report_provider.dart';
import '../../utils/date_utils.dart';
import '../../utils/toast_manager.dart';
import '../../widgets/app_header.dart';

/// 일일 리포트 상세 화면 위젯
class DailyReportDetailScreen extends ConsumerStatefulWidget {
  final String id;
  const DailyReportDetailScreen({super.key, required this.id});

  @override
  ConsumerState<DailyReportDetailScreen> createState() =>
      _DailyReportDetailScreenState();
}

class _DailyReportDetailScreenState
    extends ConsumerState<DailyReportDetailScreen> {
  bool _isEditing = false;
  final Map<String, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    Future.microtask(
        () => ref.read(dailyReportProvider.notifier).loadReport(widget.id));
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _enterEditMode(DailyReport report) {
    for (final section in report.sections) {
      _controllers[section.id] =
          TextEditingController(text: section.content ?? '');
    }
    setState(() => _isEditing = true);
  }

  Future<void> _saveDraft() async {
    final report = ref.read(dailyReportProvider).selected;
    if (report == null) return;

    final sections = report.sections.map((s) {
      return {
        'section_id': s.id,
        'content': _controllers[s.id]?.text,
      };
    }).toList();

    final ok = await ref
        .read(dailyReportProvider.notifier)
        .updateReport(report.id, sections);
    if (mounted) {
      if (ok) {
        setState(() => _isEditing = false);
        ToastManager().success(context, 'Draft saved');
      } else {
        ToastManager().error(context, 'Failed to save');
      }
    }
  }

  Future<void> _submit() async {
    final report = ref.read(dailyReportProvider).selected;
    if (report == null) return;

    // 편집 모드라면 먼저 저장
    if (_isEditing) {
      final sections = report.sections.map((s) {
        return {
          'section_id': s.id,
          'content': _controllers[s.id]?.text,
        };
      }).toList();

      final saved = await ref
          .read(dailyReportProvider.notifier)
          .updateReport(report.id, sections);
      if (!saved) {
        if (mounted) ToastManager().error(context, 'Failed to save');
        return;
      }
    }

    final ok = await ref
        .read(dailyReportProvider.notifier)
        .submitReport(report.id);
    if (mounted) {
      if (ok) {
        setState(() => _isEditing = false);
        ToastManager().success(context, 'Report submitted');
      } else {
        ToastManager().error(context, 'Failed to submit');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(dailyReportProvider);
    final report = state.selected;
    final user = ref.watch(authProvider).user;
    final isOwner = user != null && report != null && report.authorId == user.id;
    final isDraft = report?.status == 'draft';

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          AppHeader(
            title: 'Report Detail',
            isDetail: true,
            onBack: () => context.pop(),
          ),
          if (state.isLoading && report == null)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (report == null)
            Expanded(
              child: Center(
                child: Text(state.error ?? 'Report not found',
                    style: const TextStyle(color: AppColors.textMuted)),
              ),
            )
          else ...[
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(report),
                    const SizedBox(height: 8),
                    _buildSections(report),
                    if (report.comments.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _buildComments(report),
                    ],
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
            // Action buttons for draft reports
            if (isDraft && isOwner)
              SafeArea(
                top: false,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                  color: AppColors.white,
                  child: _isEditing
                      ? Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: state.isLoading ? null : _saveDraft,
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(
                                      color: AppColors.border),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(12)),
                                ),
                                child: const Text(
                                  'Save Draft',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: state.isLoading ? null : _submit,
                                child: state.isLoading
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white),
                                      )
                                    : const Text('Submit'),
                              ),
                            ),
                          ],
                        )
                      : Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _enterEditMode(report),
                                icon: const Icon(Icons.edit, size: 18),
                                label: const Text('Edit'),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(
                                      color: AppColors.border),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(12)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: state.isLoading ? null : _submit,
                                child: state.isLoading
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white),
                                      )
                                    : const Text('Submit'),
                              ),
                            ),
                          ],
                        ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  /// 리포트 헤더: 날짜, 시간대, 매장, 상태
  Widget _buildHeader(DailyReport report) {
    Color statusColor;
    Color statusBgColor;
    switch (report.status) {
      case 'submitted':
        statusColor = AppColors.success;
        statusBgColor = AppColors.successBg;
        break;
      case 'reviewed':
        statusColor = AppColors.accent;
        statusBgColor = AppColors.accentBg;
        break;
      default:
        statusColor = AppColors.warning;
        statusBgColor = AppColors.warningBg;
    }

    return Container(
      width: double.infinity,
      color: AppColors.white,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusBgColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  report.statusLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.bg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  report.periodLabel,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            formatFixedDate(report.reportDate),
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 4),
          if (report.storeName != null)
            Text(
              report.storeName!,
              style: const TextStyle(
                  fontSize: 14, color: AppColors.textSecondary),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.person_outline,
                  size: 16, color: AppColors.textMuted),
              const SizedBox(width: 4),
              Text(
                report.authorName ?? 'Unknown',
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(width: 12),
              const Icon(Icons.access_time,
                  size: 16, color: AppColors.textMuted),
              const SizedBox(width: 4),
              Text(
                formatDateTime(report.createdAt),
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textSecondary),
              ),
            ],
          ),
          if (report.status == 'submitted' && report.submittedAt != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.successBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle,
                      size: 16, color: AppColors.success),
                  const SizedBox(width: 6),
                  Text(
                    'Submitted ${formatActionTime(report.submittedAt!)}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.success,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 섹션 내용 (읽기 또는 편집 모드)
  Widget _buildSections(DailyReport report) {
    final sections = report.sections.toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    return Container(
      width: double.infinity,
      color: AppColors.white,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Report Content',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 16),
          ...sections.map((section) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    section.title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.accent,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_isEditing)
                    TextField(
                      controller: _controllers[section.id],
                      maxLines: 5,
                      minLines: 3,
                      style: const TextStyle(
                          fontSize: 14, color: AppColors.text),
                      decoration: const InputDecoration(
                        hintText: 'Enter content...',
                        hintStyle: TextStyle(
                            color: AppColors.textMuted, fontSize: 14),
                        alignLabelWithHint: true,
                      ),
                    )
                  else
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.bg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        section.content?.isNotEmpty == true
                            ? section.content!
                            : '(No content)',
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.6,
                          color: section.content?.isNotEmpty == true
                              ? AppColors.text
                              : AppColors.textMuted,
                        ),
                      ),
                    ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  /// 댓글 섹션 (읽기 전용)
  Widget _buildComments(DailyReport report) {
    return Container(
      width: double.infinity,
      color: AppColors.white,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Comments (${report.comments.length})',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 12),
          ...report.comments.map((comment) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: AppColors.accentBg,
                    child: Text(
                      (comment.userName ?? '?')[0].toUpperCase(),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.accent,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              comment.userName ?? 'Unknown',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.text,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              timeAgo(comment.createdAt),
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          comment.content,
                          style: const TextStyle(
                            fontSize: 14,
                            height: 1.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
