/// 이슈 리포트 디테일 화면 — 본문 + 상태 전이 + 댓글.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:htm_core/htm_core.dart';

import '../../models/issue_report.dart';
import '../../providers/auth_provider.dart';
import '../../providers/issue_report_provider.dart';
import '../../services/issue_report_service.dart';
import '../../widgets/app_header.dart';
import '../../utils/date_utils.dart';

class IssueReportDetailScreen extends ConsumerStatefulWidget {
  final String id;
  const IssueReportDetailScreen({super.key, required this.id});

  @override
  ConsumerState<IssueReportDetailScreen> createState() =>
      _IssueReportDetailScreenState();
}

class _IssueReportDetailScreenState
    extends ConsumerState<IssueReportDetailScreen> {
  IssueReport? _report;
  Map<String, dynamic>? _linkOptions;
  bool _loading = true;
  bool _busy = false;
  final _commentCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r =
          await ref.read(issueReportServiceProvider).getReport(widget.id);
      // 매장이 있고 links 가 비어있지 않으면 이름 해석용 옵션 fetch
      Map<String, dynamic>? options;
      if (r.storeId != null && _hasAnyLinks(r.links)) {
        try {
          options = await ref
              .read(issueReportServiceProvider)
              .getLinkOptions(r.storeId!);
        } catch (_) {
          // 권한 부족/네트워크 실패 시 ID fallback
        }
      }
      if (!mounted) return;
      setState(() {
        _report = r;
        _linkOptions = options;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _transition(String next) async {
    setState(() => _busy = true);
    try {
      await ref.read(issueReportServiceProvider).transition(widget.id, next);
      await _load();
      // 목록 invalidate
      await ref.read(issueReportProvider.notifier).load();
    } catch (e) {
      if (!mounted) return;
      await AppModal.show(
        context,
        title: 'Status change failed',
        message: e.toString(),
        type: ModalType.error,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addComment() async {
    final content = _commentCtrl.text.trim();
    if (content.isEmpty) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(issueReportServiceProvider)
          .addComment(widget.id, content);
      _commentCtrl.clear();
      await _load();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'closed':
        return AppColors.success;
      case 'in_progress':
        return AppColors.accent;
      default:
        return AppColors.warning;
    }
  }

  Color _severityColor(String? s) {
    switch (s) {
      case 'critical':
        return AppColors.danger;
      case 'high':
        return AppColors.warning;
      case 'medium':
        return AppColors.accent;
      default:
        return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final canUpdate = user?.hasPermission('reports:update') ?? false;

    if (_loading) {
      return const Scaffold(
        backgroundColor: AppColors.bg,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final r = _report;
    if (r == null) {
      return Scaffold(
        backgroundColor: AppColors.bg,
        body: const Center(child: Text('Not found')),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            AppHeader(
              title: 'Issue',
              isDetail: true,
              onBack: () => context.pop(),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _badge(r.status.toUpperCase(), _statusColor(r.status)),
                        if (r.severity != null) ...[
                          const SizedBox(width: 6),
                          _badge(
                            r.severity!.toUpperCase(),
                            _severityColor(r.severity),
                          ),
                        ],
                        if (r.category != null) ...[
                          const SizedBox(width: 6),
                          _badge(r.category!, AppColors.textMuted),
                        ],
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      r.title ?? '(no title)',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      children: [
                        if (r.storeName != null)
                          Text(
                            '📍 ${r.storeName}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted,
                            ),
                          ),
                        if (r.authorName != null)
                          Text(
                            '✍️ ${r.authorName}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted,
                            ),
                          ),
                        Text(
                          '🕒 ${formatDateTime(r.createdAt)}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                    if (canUpdate && r.status != 'closed') ...[
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          if (r.status == 'open')
                            _actionButton(
                              'Start',
                              _busy ? null : () => _transition('in_progress'),
                            ),
                          if (r.status == 'in_progress')
                            _actionButton(
                              'Close',
                              _busy ? null : () => _transition('closed'),
                            ),
                        ],
                      ),
                    ],
                    if (r.description != null && r.description!.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Text(
                          r.description!,
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.text,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                    if (_hasAnyLinks(r.links)) ...[
                      const SizedBox(height: 20),
                      _relatedResourcesSection(r.links),
                    ],
                    if (r.customFieldValues.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      ...r.customFieldValues.entries.map((e) => Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${e.key}: ',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    '${e.value}',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: AppColors.text,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )),
                    ],
                    const SizedBox(height: 24),
                    const Text(
                      'Comments',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...r.comments.map((c) => Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    c.userName ?? 'Unknown',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.text,
                                    ),
                                  ),
                                  Text(
                                    formatDateTime(c.createdAt),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                c.content,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.text,
                                ),
                              ),
                            ],
                          ),
                        )),
                    if (canUpdate) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: _commentCtrl,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: 'Write a comment…',
                          filled: true,
                          fillColor: AppColors.white,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton(
                          onPressed: _busy ? null : _addComment,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accent,
                            foregroundColor: AppColors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text('Post'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _actionButton(String label, VoidCallback? onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.accent,
        foregroundColor: AppColors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: Text(label),
    );
  }

  bool _hasAnyLinks(Map<String, List<String>> links) {
    for (final v in links.values) {
      if (v.isNotEmpty) return true;
    }
    return false;
  }

  Widget _relatedResourcesSection(Map<String, List<String>> links) {
    // _linkOptions 로 이름 해석. 매장에 속하지 않거나 옵션 fetch 실패 시 ID fallback.
    final opt = _linkOptions;
    Map<String, String> labelMap(String key, String Function(Map) build) {
      final out = <String, String>{};
      if (opt == null) return out;
      final list = (opt[key] as List?) ?? const [];
      for (final raw in list) {
        if (raw is Map) {
          final id = raw['id'] as String?;
          if (id != null) out[id] = build(raw);
        }
      }
      return out;
    }

    String joinDot(List<String?> parts) =>
        parts.where((p) => p != null && p.trim().isNotEmpty).join(' · ');

    final scheduleLabels = labelMap('schedules', (s) {
      final startHm = hmFromIso(s['start_at']) ?? s['start_time'] as String?;
      final endHm = hmFromIso(s['end_at']) ?? s['end_time'] as String?;
      final timeRange =
          (startHm != null && endHm != null) ? '$startHm–$endHm' : null;
      return joinDot([
        (s['operating_day'] ?? s['work_date']) as String?,
        timeRange,
        (s['work_role_name'] ?? s['position_snapshot']) as String?,
        s['user_name'] as String?,
      ]);
    });
    final checklistLabels = labelMap('checklist_instances', (c) {
      return joinDot([
        c['work_date'] as String?,
        c['template_title'] as String?,
        c['user_name'] as String?,
      ]);
    });
    final positionLabels = labelMap('positions', (p) => (p['name'] as String?) ?? '');
    final workRoleLabels = labelMap('work_roles', (w) {
      final n = w['name'] ?? w['position_name'] ?? '(unnamed)';
      final pos = w['position_name'];
      return pos != null && pos != n ? '$n · $pos' : '$n';
    });
    final userLabels = labelMap('users', (u) {
      final display = (u['full_name'] as String?) ?? (u['username'] as String? ?? '');
      final role = u['role_name'] as String?;
      return role != null && role.isNotEmpty ? '$display ($role)' : display;
    });

    final sections = <(String, List<String>, Map<String, String>)>[
      ('Schedules', links['schedule_ids'] ?? const [], scheduleLabels),
      ('Checklist instances', links['checklist_instance_ids'] ?? const [], checklistLabels),
      ('Positions', links['position_ids'] ?? const [], positionLabels),
      ('Work roles', links['work_role_ids'] ?? const [], workRoleLabels),
      ('Related people', links['related_user_ids'] ?? const [], userLabels),
    ];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Related Resources',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          for (final (label, ids, labels) in sections)
            if (ids.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 110,
                      child: Text(
                        label,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: ids.map((id) {
                          final text = labels[id];
                          final display = (text != null && text.isNotEmpty)
                              ? text
                              : '${id.substring(0, 8)}…';
                          return Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.bg,
                              border: Border.all(color: AppColors.border),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              display,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.text,
                              ),
                            ),
                          );
                        }).toList(),
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
}
