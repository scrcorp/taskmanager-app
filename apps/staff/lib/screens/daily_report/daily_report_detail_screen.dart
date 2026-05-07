/// 일일 리포트 상세/생성/편집 통합 화면
///
/// - id가 없으면 생성 모드 (매장/날짜/시간대 선택 후 섹션 작성)
/// - id가 있으면 조회 모드 (draft 시 편집 가능)
/// - 섹션 description은 snapshot으로 보존되어 템플릿 삭제와 무관하게 표시
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../config/theme.dart';
import '../../models/daily_report.dart';
import '../../models/store.dart';
import '../../providers/auth_provider.dart';
import '../../providers/daily_report_provider.dart';
import '../../services/daily_report_service.dart';
import '../../utils/date_utils.dart';
import '../../widgets/app_header.dart';
import '../../widgets/app_modal.dart';

class DailyReportDetailScreen extends ConsumerStatefulWidget {
  final String? id;
  const DailyReportDetailScreen({super.key, this.id});

  @override
  ConsumerState<DailyReportDetailScreen> createState() =>
      _DailyReportDetailScreenState();
}

class _DailyReportDetailScreenState
    extends ConsumerState<DailyReportDetailScreen> {
  // -- Common state --
  bool _isEditing = false;
  final Map<String, TextEditingController> _controllers = {};
  Set<String> _emptySectionIds = {};

  // -- Create mode state --
  bool get _isCreateMode => widget.id == null;
  Store? _selectedStore;
  DateTime _selectedDate = DateTime.now();
  String _selectedPeriod = 'lunch';
  DailyReportTemplate? _template;
  DailyReport? _createdReport; // report created during create flow
  bool _isCreating = false;
  List<Store> _stores = [];
  bool _isLoadingStores = true;

  @override
  void initState() {
    super.initState();
    if (_isCreateMode) {
      Future.microtask(() => _loadStores());
    } else {
      Future.microtask(
          () => ref.read(dailyReportProvider.notifier).loadReport(widget.id!));
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  // ─── Create mode helpers ───

  Future<void> _loadStores() async {
    try {
      final service = ref.read(dailyReportServiceProvider);
      final data = await service.getMyStores();
      if (mounted) {
        setState(() {
          _stores = data.map((e) => Store.fromJson(e)).toList();
          _isLoadingStores = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingStores = false);
    }
  }

  Future<void> _showDuplicateDialog(String existingId) async {
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Report Exists'),
        content: const Text(
          'A report already exists for this store/date/period.\nWould you like to view the existing report?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Go to Report'),
          ),
        ],
      ),
    );
    if (go == true && mounted) {
      context.pushReplacement('/daily-reports/$existingId');
    }
  }

  Future<void> _createAndLoadTemplate() async {
    if (_selectedStore == null) {
      await AppModal.show(
        context,
        title: 'Heads up',
        message: 'Please select a store',
        type: ModalType.warning,
      );
      return;
    }
    setState(() => _isCreating = true);

    await ref
        .read(dailyReportProvider.notifier)
        .loadTemplate(storeId: _selectedStore!.id);
    final template = ref.read(dailyReportProvider).template;

    if (template == null) {
      if (mounted) {
        await AppModal.show(
          context,
          title: "Couldn't load template",
          message: 'Failed to load template',
          type: ModalType.error,
        );
      }
      setState(() => _isCreating = false);
      return;
    }

    DailyReport? report;
    try {
      final service = ref.read(dailyReportServiceProvider);
      report = await service.createReport(
        storeId: _selectedStore!.id,
        reportDate: DateFormat('yyyy-MM-dd').format(_selectedDate),
        period: _selectedPeriod,
        templateId: template.id,
      );
    } on DioException catch (e) {
      if (!mounted) return;
      if (e.response?.statusCode == 409) {
        final detail = e.response?.data['detail'];
        final existingId = detail is Map ? detail['existing_report_id'] : null;
        if (existingId != null) {
          setState(() => _isCreating = false);
          await _showDuplicateDialog(existingId as String);
          return;
        }
      }
      await AppModal.show(
        context,
        title: "Couldn't create report",
        message: 'Failed to create report',
        type: ModalType.error,
      );
      setState(() => _isCreating = false);
      return;
    } catch (_) {
      if (mounted) {
        await AppModal.show(
          context,
          title: "Couldn't create report",
          message: 'Failed to create report',
          type: ModalType.error,
        );
      }
      setState(() => _isCreating = false);
      return;
    }

    _initControllers(report.sections);
    setState(() {
      _template = template;
      _createdReport = report;
      _isEditing = true;
      _isCreating = false;
    });
  }

  // ─── Common helpers ───

  void _initControllers(List<DailyReportSection> sections) {
    for (final c in _controllers.values) {
      c.dispose();
    }
    _controllers.clear();
    for (final section in sections) {
      _controllers[section.key] =
          TextEditingController(text: section.content ?? '');
    }
  }

  void _enterEditMode(DailyReport report) {
    _initControllers(report.sections);
    setState(() => _isEditing = true);
  }

  /// Current report: either created (create mode) or loaded (detail mode)
  DailyReport? get _currentReport =>
      _isCreateMode ? _createdReport : ref.read(dailyReportProvider).selected;

  Future<void> _saveDraft() async {
    final report = _currentReport;
    if (report == null) return;

    final sections = report.sections.map((s) {
      return {
        'sort_order': s.sortOrder,
        'content': _controllers[s.key]?.text,
      };
    }).toList();

    final ok = await ref
        .read(dailyReportProvider.notifier)
        .updateReport(report.id, sections);
    if (mounted) {
      if (ok) {
        await AppModal.show(
          context,
          title: 'Saved',
          message: 'Draft saved',
          type: ModalType.success,
        );
        if (!mounted) return;
        await ref.read(dailyReportProvider.notifier).loadReports();
        if (mounted) context.pop();
      } else {
        await AppModal.show(
          context,
          title: "Couldn't save",
          message: 'Failed to save',
          type: ModalType.error,
        );
      }
    }
  }

  Future<void> _submit() async {
    final report = _currentReport;
    if (report == null) return;

    // Validate required sections only
    final empty = <String>{};
    for (final section in report.sections) {
      if (!section.isRequired) continue;
      final text = _isEditing
          ? (_controllers[section.key]?.text.trim() ?? '')
          : (section.content?.trim() ?? '');
      if (text.isEmpty) {
        empty.add(section.key);
      }
    }
    if (empty.isNotEmpty) {
      if (!_isEditing) _enterEditMode(report);
      setState(() => _emptySectionIds = empty);
      return;
    }

    // Save first if editing
    if (_isEditing) {
      final sections = report.sections.map((s) {
        return {
          'sort_order': s.sortOrder,
          'content': _controllers[s.key]?.text,
        };
      }).toList();

      final saved = await ref
          .read(dailyReportProvider.notifier)
          .updateReport(report.id, sections);
      if (!saved) {
        if (mounted) {
          await AppModal.show(
            context,
            title: "Couldn't save",
            message: 'Failed to save',
            type: ModalType.error,
          );
        }
        return;
      }
    }

    final ok = await ref
        .read(dailyReportProvider.notifier)
        .submitReport(report.id);
    if (mounted) {
      if (ok) {
        setState(() {
          _isEditing = false;
          _emptySectionIds = {};
        });
        await AppModal.show(
          context,
          title: 'Submitted',
          message: 'Report submitted',
          type: ModalType.success,
        );
        if (!mounted) return;
        await ref.read(dailyReportProvider.notifier).loadReports();
        if (mounted) context.pop();
      } else {
        await AppModal.show(
          context,
          title: "Couldn't submit",
          message: 'Failed to submit',
          type: ModalType.error,
        );
      }
    }
  }

  Future<void> _deleteReport() async {
    final report = _currentReport;
    if (report == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Draft'),
        content: const Text('Are you sure you want to delete this draft?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Color(0xFFDC2626))),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    final ok = await ref.read(dailyReportProvider.notifier).deleteReport(report.id);
    if (mounted) {
      if (ok) {
        await AppModal.show(
          context,
          title: 'Deleted',
          message: 'Draft deleted',
          type: ModalType.success,
        );
        if (!mounted) return;
        await ref.read(dailyReportProvider.notifier).loadReports();
        if (mounted) context.pop();
      } else {
        await AppModal.show(
          context,
          title: "Couldn't delete",
          message: 'Failed to delete',
          type: ModalType.error,
        );
      }
    }
  }

  // ─── Build ───

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(dailyReportProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          AppHeader(
            title: _isCreateMode ? 'New Report' : 'Report Detail',
            isDetail: true,
            onBack: () => context.pop(),
          ),
          Expanded(child: _buildBody(state)),
        ],
      ),
    );
  }

  Widget _buildBody(DailyReportState state) {
    // Create mode: show setup form first, then section form
    if (_isCreateMode) {
      if (_createdReport == null) {
        return _buildSetupForm();
      }
      return _buildReportView(_createdReport!, state);
    }

    // Detail mode: show loaded report
    final report = state.selected;
    if (state.isLoading && report == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (report == null) {
      return Center(
        child: Text(state.error ?? 'Report not found',
            style: const TextStyle(color: AppColors.textMuted)),
      );
    }
    return _buildReportView(report, state);
  }

  /// Report view: header + sections + comments + action buttons
  Widget _buildReportView(DailyReport report, DailyReportState state) {
    final user = ref.watch(authProvider).user;
    final isOwner =
        user != null && report.authorId == user.id;
    final isDraft = report.status == 'draft';

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(report),
                const SizedBox(height: 8),
                _buildSections(report),
                if (!_isCreateMode && report.comments.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _buildComments(report),
                ],
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
        // Action buttons for draft
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
                              side:
                                  const BorderSide(color: AppColors.border),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
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
                        IconButton(
                          onPressed: state.isLoading ? null : _deleteReport,
                          icon: const Icon(Icons.delete_outline, size: 22),
                          color: const Color(0xFFDC2626),
                          style: IconButton.styleFrom(
                            side: const BorderSide(color: AppColors.border),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.all(12),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _enterEditMode(report),
                            icon: const Icon(Icons.edit, size: 18),
                            label: const Text('Edit'),
                            style: OutlinedButton.styleFrom(
                              side:
                                  const BorderSide(color: AppColors.border),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
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
    );
  }

  // ─── Setup form (create mode step 1) ───

  Widget _buildSetupForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Store selector
          const Text('Store',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text)),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border, width: 1.5),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<Store>(
                value: _selectedStore,
                isExpanded: true,
                hint: const Text('Select store',
                    style: TextStyle(color: AppColors.textMuted)),
                items: _stores.map((s) {
                  return DropdownMenuItem(value: s, child: Text(s.name));
                }).toList(),
                onChanged: (v) => setState(() => _selectedStore = v),
              ),
            ),
          ),
          if (_isLoadingStores)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: SizedBox(
                height: 16,
                width: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else if (_stores.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'No stores assigned',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
            ),
          const SizedBox(height: 20),

          // Date picker
          const Text('Date',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text)),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _selectedDate,
                firstDate:
                    DateTime.now().subtract(const Duration(days: 30)),
                lastDate: DateTime.now(),
              );
              if (picked != null) setState(() => _selectedDate = picked);
            },
            child: Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border, width: 1.5),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      DateFormat('yyyy-MM-dd (EEE)')
                          .format(_selectedDate),
                      style: const TextStyle(
                          fontSize: 14, color: AppColors.text),
                    ),
                  ),
                  const Icon(Icons.calendar_today,
                      size: 18, color: AppColors.textMuted),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Period selector
          const Text('Period',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text)),
          const SizedBox(height: 8),
          Row(
            children: [
              _PeriodChip(
                label: 'Lunch',
                isSelected: _selectedPeriod == 'lunch',
                onTap: () => setState(() => _selectedPeriod = 'lunch'),
              ),
              const SizedBox(width: 12),
              _PeriodChip(
                label: 'Dinner',
                isSelected: _selectedPeriod == 'dinner',
                onTap: () => setState(() => _selectedPeriod = 'dinner'),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Next button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isCreating ? null : _createAndLoadTemplate,
              child: _isCreating
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Start Writing'),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Report header ───

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

  // ─── Sections (read or edit) ───

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
            final hasError = _emptySectionIds.contains(section.key);
            // Use snapshotted description from section
            final hintText = section.description ?? 'Enter content...';

            return Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        section.title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.accent,
                        ),
                      ),
                      if (section.isRequired)
                        const Text(
                          ' *',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFDC2626),
                          ),
                        )
                      else
                        const Text(
                          '  (Optional)',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_isEditing)
                    TextField(
                      controller: _controllers[section.key],
                      maxLines: 5,
                      minLines: 3,
                      style: const TextStyle(
                          fontSize: 14, color: AppColors.text),
                      decoration: InputDecoration(
                        hintText: hintText,
                        hintStyle: const TextStyle(
                            color: AppColors.textMuted, fontSize: 14),
                        alignLabelWithHint: true,
                        enabledBorder: hasError
                            ? OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                    color: Color(0xFFDC2626), width: 1.5),
                              )
                            : null,
                        focusedBorder: hasError
                            ? OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(
                                    color: Color(0xFFDC2626), width: 2),
                              )
                            : null,
                      ),
                      onChanged: (_) {
                        if (_emptySectionIds.contains(section.key)) {
                          setState(
                              () => _emptySectionIds.remove(section.key));
                        }
                      },
                    )
                  else
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.bg,
                        borderRadius: BorderRadius.circular(8),
                        border: hasError
                            ? Border.all(
                                color: const Color(0xFFDC2626),
                                width: 1.5)
                            : null,
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
                  if (hasError)
                    const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Text(
                        'This field is required',
                        style: TextStyle(
                            fontSize: 12, color: Color(0xFFDC2626)),
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

  // ─── Comments (read-only) ───

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

class _PeriodChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _PeriodChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accent : AppColors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppColors.accent : AppColors.border,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
