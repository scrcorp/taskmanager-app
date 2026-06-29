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
import 'package:htm_core/htm_core.dart';
import '../../l10n/app_localizations.dart';
import '../../models/daily_report.dart';
import '../../models/store.dart';
import '../../providers/auth_provider.dart';
import '../../providers/daily_report_provider.dart';
import '../../services/daily_report_service.dart';
import '../../utils/date_utils.dart';
import '../../widgets/app_header.dart';

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
  // Effective report types (period options) for the selected store.
  List<EffectiveReportType> _reportTypes = [];
  bool _loadingTypes = false;

  @override
  void initState() {
    super.initState();
    if (_isCreateMode) {
      Future.microtask(() => _loadStores());
    } else {
      Future.microtask(_loadDetail);
    }
  }

  /// Detail mode: load report, then its store template (for section
  /// description/required hints — these are not carried in the report payload).
  Future<void> _loadDetail() async {
    await ref.read(dailyReportProvider.notifier).loadReport(widget.id!);
    if (!mounted) return;
    final r = ref.read(dailyReportProvider).selected;
    if (r == null) return;
    try {
      final tpl = await ref
          .read(dailyReportServiceProvider)
          .getTemplate(storeId: r.storeId);
      if (mounted) setState(() => _template = tpl);
    } catch (_) {
      // Template is optional for display; ignore load failures.
    }
  }

  /// Resolve section description/required from the template (payload sections
  /// do not carry them). Falls back to whatever the section already holds.
  ({String? description, bool isRequired}) _metaFor(DailyReportSection s) {
    final tpl = _template;
    if (tpl == null) {
      return (description: s.description, isRequired: s.isRequired);
    }
    DailyReportTemplateSection? match;
    for (final ts in tpl.sections) {
      if (s.templateSectionId != null && ts.id == s.templateSectionId) {
        match = ts;
        break;
      }
    }
    if (match == null) {
      for (final ts in tpl.sections) {
        if (ts.sortOrder == s.sortOrder) {
          match = ts;
          break;
        }
      }
    }
    return (
      description: match?.description ?? s.description,
      isRequired: match?.isRequired ?? s.isRequired,
    );
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

  /// Store selected → load that store's effective report types (period options).
  Future<void> _onStoreSelected(Store? v) async {
    setState(() {
      _selectedStore = v;
      _reportTypes = [];
    });
    if (v == null) return;
    setState(() => _loadingTypes = true);
    final types = await ref
        .read(dailyReportProvider.notifier)
        .loadReportTypes(storeId: v.id);
    if (!mounted) return;
    setState(() {
      _reportTypes = types;
      _loadingTypes = false;
      // Default the period to the first active type if the current pick is gone.
      if (types.isNotEmpty && !types.any((t) => t.code == _selectedPeriod)) {
        _selectedPeriod = types.first.code;
      }
    });
  }

  Future<void> _showDuplicateDialog(String existingId) async {
    final t = AppL10n.of(context);
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.drExistsTitle),
        content: Text(t.drExistsMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(t.actionCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(t.drExistsGo),
          ),
        ],
      ),
    );
    if (go == true && mounted) {
      context.pushReplacement('/daily-reports/$existingId');
    }
  }

  Future<void> _createAndLoadTemplate() async {
    final t = AppL10n.of(context);
    if (_selectedStore == null) {
      await AppModal.show(
        context,
        title: t.commonHeadsUp,
        message: t.drSelectStorePrompt,
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
          title: t.drTemplateLoadFailedTitle,
          message: t.drTemplateLoadFailedMessage,
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
        title: t.drCreateFailedTitle,
        message: t.drCreateFailedMessage,
        type: ModalType.error,
      );
      setState(() => _isCreating = false);
      return;
    } catch (_) {
      if (mounted) {
        await AppModal.show(
          context,
          title: t.drCreateFailedTitle,
          message: t.drCreateFailedMessage,
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
    final t = AppL10n.of(context);
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
          title: t.commonSavedTitle,
          message: t.drDraftSaved,
          type: ModalType.success,
        );
        if (!mounted) return;
        await ref.read(dailyReportProvider.notifier).loadReports();
        if (mounted) context.pop();
      } else {
        await AppModal.show(
          context,
          title: t.commonSaveFailedTitle,
          message: t.drSaveFailed,
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
      if (!_metaFor(section).isRequired) continue;
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
    final t = AppL10n.of(context);
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
            title: t.commonSaveFailedTitle,
            message: t.drSaveFailed,
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
          title: t.drSubmittedTitle,
          message: t.drSubmittedMessage,
          type: ModalType.success,
        );
        if (!mounted) return;
        await ref.read(dailyReportProvider.notifier).loadReports();
        if (mounted) context.pop();
      } else {
        await AppModal.show(
          context,
          title: t.drSubmitFailedTitle,
          message: t.drSubmitFailedMessage,
          type: ModalType.error,
        );
      }
    }
  }

  Future<void> _deleteReport() async {
    final t = AppL10n.of(context);
    final report = _currentReport;
    if (report == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.drDeleteTitle),
        content: Text(t.drDeleteMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(t.actionCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(t.actionDelete, style: const TextStyle(color: Color(0xFFDC2626))),
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
          title: t.drDeletedTitle,
          message: t.drDeletedMessage,
          type: ModalType.success,
        );
        if (!mounted) return;
        await ref.read(dailyReportProvider.notifier).loadReports();
        if (mounted) context.pop();
      } else {
        await AppModal.show(
          context,
          title: t.drDeleteFailedTitle,
          message: t.drDeleteFailedMessage,
          type: ModalType.error,
        );
      }
    }
  }

  Future<void> _acknowledge() async {
    final t = AppL10n.of(context);
    final report = _currentReport;
    if (report == null) return;

    final ok = await ref
        .read(dailyReportProvider.notifier)
        .acknowledgeReport(report.id);
    if (!mounted) return;
    if (ok) {
      await AppModal.show(
        context,
        title: t.drAcknowledgedTitle,
        message: t.drAcknowledgedMessage,
        type: ModalType.success,
      );
    } else {
      await AppModal.show(
        context,
        title: t.drAcknowledgeFailedTitle,
        message: t.drAcknowledgeFailedMessage,
        type: ModalType.error,
      );
    }
  }

  // ─── Build ───

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);
    final state = ref.watch(dailyReportProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          AppHeader(
            title: _isCreateMode ? t.drHeaderNew : t.drHeaderDetail,
            isDetail: true,
            onBack: () => context.pop(),
          ),
          Expanded(child: _buildBody(state)),
        ],
      ),
    );
  }

  Widget _buildBody(DailyReportState state) {
    final t = AppL10n.of(context);
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
        child: Text(state.error ?? t.drNotFound,
            style: const TextStyle(color: AppColors.textMuted)),
      );
    }
    return _buildReportView(report, state);
  }

  /// Report view: header + sections + comments + action buttons
  Widget _buildReportView(DailyReport report, DailyReportState state) {
    final t = AppL10n.of(context);
    final user = ref.watch(authProvider).user;
    final isOwner =
        user != null && report.authorId == user.id;
    final isDraft = report.status == 'draft';
    // A supervisor (non-author) can acknowledge a submitted/reviewed report.
    final canAck = user != null && user.hasPermission('reports:acknowledge');
    final alreadyAcked = user != null && report.acknowledgedBy(user.id);
    final showAckBar =
        !_isCreateMode && !isOwner && !isDraft && canAck;

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
                if (!_isCreateMode && report.acknowledgements.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _buildAcknowledgements(report),
                ],
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
        // Acknowledge action for supervisors (non-author)
        if (showAckBar)
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              color: AppColors.white,
              child: alreadyAcked
                  ? OutlinedButton.icon(
                      onPressed: null,
                      icon: const Icon(Icons.check_circle,
                          size: 18, color: AppColors.success),
                      label: Text(t.drAcknowledged),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        side: const BorderSide(color: AppColors.border),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    )
                  : ElevatedButton.icon(
                      onPressed: state.isLoading ? null : _acknowledge,
                      icon: const Icon(Icons.done_all, size: 18),
                      label: Text(t.drAcknowledge),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
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
                            child: Text(
                              t.drSaveDraftButton,
                              style: const TextStyle(
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
                                : Text(t.actionSubmit),
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
                            label: Text(t.actionEdit),
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
                                : Text(t.actionSubmit),
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
    final t = AppL10n.of(context);
    final localeStr = Localizations.localeOf(context).toString();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Store selector
          Text(t.drStoreLabel,
              style: const TextStyle(
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
                hint: Text(t.drSelectStoreHint,
                    style: const TextStyle(color: AppColors.textMuted)),
                items: _stores.map((s) {
                  return DropdownMenuItem(value: s, child: Text(s.name));
                }).toList(),
                onChanged: _onStoreSelected,
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
                t.inventoryNoStoresTitle,
                style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
            ),
          const SizedBox(height: 20),

          // Date picker
          Text(t.drDateLabel,
              style: const TextStyle(
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
                      DateFormat.yMMMEd(localeStr).format(_selectedDate),
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
          Text(t.drPeriodLabel,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text)),
          const SizedBox(height: 8),
          _buildPeriodSelector(t),
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
                  : Text(t.drStartWriting),
            ),
          ),
        ],
      ),
    );
  }

  /// Period selector — driven by the store's effective report types.
  /// Falls back to lunch/dinner before a store/types are loaded.
  Widget _buildPeriodSelector(AppL10n t) {
    if (_loadingTypes) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 4),
        child: SizedBox(
          height: 16,
          width: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    final List<({String code, String label})> options;
    if (_reportTypes.isNotEmpty) {
      options =
          _reportTypes.map((e) => (code: e.code, label: e.label)).toList();
    } else {
      options = [
        (code: 'lunch', label: t.drPeriodLunch),
        (code: 'dinner', label: t.drPeriodDinner),
      ];
    }

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: options.map((o) {
        return _PeriodChip(
          label: o.label,
          isSelected: _selectedPeriod == o.code,
          onTap: () => setState(() => _selectedPeriod = o.code),
        );
      }).toList(),
    );
  }

  // ─── Report header ───

  Widget _buildHeader(DailyReport report) {
    final t = AppL10n.of(context);
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
                report.authorName ?? AppL10n.of(context).commonUnknown,
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
          // Deadline + overdue/late indicator
          if (report.deadlineAt != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  report.isOverdue
                      ? Icons.warning_amber_rounded
                      : Icons.schedule,
                  size: 16,
                  color: report.isOverdue
                      ? AppColors.warning
                      : AppColors.textMuted,
                ),
                const SizedBox(width: 4),
                Text(
                  t.drDeadline(formatActionTime(report.deadlineAt!)),
                  style: TextStyle(
                    fontSize: 13,
                    color: report.isOverdue
                        ? AppColors.warning
                        : AppColors.textSecondary,
                    fontWeight:
                        report.isOverdue ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
                if (report.isOverdue) ...[
                  const SizedBox(width: 6),
                  _miniBadge(t.drOverdue, AppColors.warning, AppColors.warningBg),
                ] else if (report.isLate) ...[
                  const SizedBox(width: 6),
                  _miniBadge(t.drLate, AppColors.warning, AppColors.warningBg),
                ],
              ],
            ),
          ],
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
                    t.drSubmittedAt(formatActionTime(report.submittedAt!)),
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
          // Reviewed banner
          if (report.status == 'reviewed' && report.reviewedByName != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.accentBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.verified_outlined,
                      size: 16, color: AppColors.accent),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      report.reviewedAt != null
                          ? t.drReviewedByAt(report.reviewedByName!,
                              formatActionTime(report.reviewedAt!))
                          : t.drReviewedBy(report.reviewedByName!),
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.accent,
                        fontWeight: FontWeight.w500,
                      ),
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

  /// Small inline pill badge.
  Widget _miniBadge(String label, Color fg, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }

  // ─── Sections (read or edit) ───

  Widget _buildSections(DailyReport report) {
    final t = AppL10n.of(context);
    final sections = report.sections.toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    return Container(
      width: double.infinity,
      color: AppColors.white,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t.drContentHeader,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 16),
          ...sections.map((section) {
            final hasError = _emptySectionIds.contains(section.key);
            // Description/required resolved from the store template.
            final meta = _metaFor(section);
            final hintText = meta.description ?? t.drEnterContent;

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
                      if (meta.isRequired)
                        const Text(
                          ' *',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFDC2626),
                          ),
                        )
                      else
                        Text(
                          t.drOptional,
                          style: const TextStyle(
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
                            : t.drNoContent,
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
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        t.drFieldRequired,
                        style: const TextStyle(
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
    final t = AppL10n.of(context);
    return Container(
      width: double.infinity,
      color: AppColors.white,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t.noticeCommentsCount(report.comments.length),
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
                              comment.userName ?? t.commonUnknown,
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

  // ─── Acknowledgements (read-only) ───

  Widget _buildAcknowledgements(DailyReport report) {
    final t = AppL10n.of(context);
    return Container(
      width: double.infinity,
      color: AppColors.white,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t.drAcknowledgedCount(report.acknowledgements.length),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 12),
          ...report.acknowledgements.map((ack) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: AppColors.successBg,
                    child: Text(
                      (ack.userName ?? '?')[0].toUpperCase(),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.success,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      ack.userName ?? t.commonUnknown,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.text,
                      ),
                    ),
                  ),
                  Text(
                    timeAgo(ack.acknowledgedAt),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
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
