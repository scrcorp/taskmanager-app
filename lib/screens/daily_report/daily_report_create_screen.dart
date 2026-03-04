/// 일일 리포트 생성 화면
///
/// 1단계: 매장 선택, 날짜 선택, 시간대(Lunch/Dinner) 선택
/// 2단계: 템플릿 섹션별 내용 작성
/// "Save Draft" 또는 "Submit" 버튼으로 저장/제출
///
/// 현재 사용자의 근무배정(assignment)에서 매장 목록을 추출하여
/// 매장 선택 드롭다운을 제공.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../config/theme.dart';
import '../../models/daily_report.dart';
import '../../models/store.dart';
import '../../providers/assignment_provider.dart';
import '../../providers/daily_report_provider.dart';
import '../../utils/toast_manager.dart';
import '../../widgets/app_header.dart';

/// 일일 리포트 생성 화면 위젯
class DailyReportCreateScreen extends ConsumerStatefulWidget {
  const DailyReportCreateScreen({super.key});

  @override
  ConsumerState<DailyReportCreateScreen> createState() =>
      _DailyReportCreateScreenState();
}

class _DailyReportCreateScreenState
    extends ConsumerState<DailyReportCreateScreen> {
  Store? _selectedStore;
  DateTime _selectedDate = DateTime.now();
  String _selectedPeriod = 'lunch';
  DailyReportTemplate? _template;
  DailyReport? _createdReport;
  final Map<String, TextEditingController> _sectionControllers = {};
  bool _isCreating = false;

  @override
  void initState() {
    super.initState();
    // 근무배정에서 매장 목록을 가져오기 위해 로드
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    Future.microtask(() {
      ref.read(assignmentProvider.notifier).loadAssignments(today);
    });
  }

  @override
  void dispose() {
    for (final c in _sectionControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  /// 근무배정에서 고유 매장 목록 추출
  List<Store> _getStoresFromAssignments() {
    final assignments = ref.read(assignmentProvider).assignments;
    final storeMap = <String, Store>{};
    for (final a in assignments) {
      storeMap[a.store.id] = a.store;
    }
    return storeMap.values.toList();
  }

  /// 리포트 생성 (draft) + 템플릿 로드
  Future<void> _createAndLoadTemplate() async {
    if (_selectedStore == null) {
      ToastManager().warning(context, 'Please select a store');
      return;
    }
    setState(() => _isCreating = true);

    // 먼저 템플릿 로드
    await ref
        .read(dailyReportProvider.notifier)
        .loadTemplate(storeId: _selectedStore!.id);
    final template = ref.read(dailyReportProvider).template;

    if (template == null) {
      if (mounted) {
        ToastManager().error(context, 'Failed to load template');
      }
      setState(() => _isCreating = false);
      return;
    }

    // 리포트 생성
    final report = await ref.read(dailyReportProvider.notifier).createReport(
          storeId: _selectedStore!.id,
          reportDate: DateFormat('yyyy-MM-dd').format(_selectedDate),
          period: _selectedPeriod,
          templateId: template.id,
        );

    if (report == null) {
      if (mounted) {
        final error = ref.read(dailyReportProvider).error ?? 'Failed to create report';
        ToastManager().error(context, error);
      }
      setState(() => _isCreating = false);
      return;
    }

    // 섹션 컨트롤러 초기화 (생성된 리포트의 섹션 사용)
    for (final section in report.sections) {
      _sectionControllers[section.id] =
          TextEditingController(text: section.content ?? '');
    }

    setState(() {
      _template = template;
      _createdReport = report;
      _isCreating = false;
    });
  }

  /// 섹션 내용 저장 (draft 유지)
  Future<void> _saveDraft() async {
    if (_createdReport == null) return;

    final sections = _createdReport!.sections.map((s) {
      return {
        'section_id': s.id,
        'content': _sectionControllers[s.id]?.text,
      };
    }).toList();

    final ok = await ref
        .read(dailyReportProvider.notifier)
        .updateReport(_createdReport!.id, sections);
    if (mounted) {
      if (ok) {
        ToastManager().success(context, 'Draft saved');
        context.pop();
      } else {
        ToastManager().error(context, 'Failed to save');
      }
    }
  }

  /// 섹션 내용 저장 후 제출
  Future<void> _saveAndSubmit() async {
    if (_createdReport == null) return;

    // 먼저 저장
    final sections = _createdReport!.sections.map((s) {
      return {
        'section_id': s.id,
        'content': _sectionControllers[s.id]?.text,
      };
    }).toList();

    final saved = await ref
        .read(dailyReportProvider.notifier)
        .updateReport(_createdReport!.id, sections);
    if (!saved) {
      if (mounted) ToastManager().error(context, 'Failed to save');
      return;
    }

    // 제출
    final ok = await ref
        .read(dailyReportProvider.notifier)
        .submitReport(_createdReport!.id);
    if (mounted) {
      if (ok) {
        ToastManager().success(context, 'Report submitted');
        context.pop();
      } else {
        ToastManager().error(context, 'Failed to submit');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(dailyReportProvider);
    final stores = _getStoresFromAssignments();

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          AppHeader(
            title: 'New Report',
            isDetail: true,
            onBack: () => context.pop(),
          ),
          Expanded(
            child: _createdReport != null
                ? _buildSectionForm(state)
                : _buildSetupForm(stores),
          ),
        ],
      ),
    );
  }

  /// 1단계: 매장/날짜/시간대 선택 폼
  Widget _buildSetupForm(List<Store> stores) {
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
                items: stores.map((s) {
                  return DropdownMenuItem(value: s, child: Text(s.name));
                }).toList(),
                onChanged: (v) => setState(() => _selectedStore = v),
              ),
            ),
          ),
          if (stores.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'No stores found from your assignments',
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
                firstDate: DateTime.now().subtract(const Duration(days: 30)),
                lastDate: DateTime.now(),
              );
              if (picked != null) setState(() => _selectedDate = picked);
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border, width: 1.5),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      DateFormat('yyyy-MM-dd (EEE)').format(_selectedDate),
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

  /// 2단계: 템플릿 섹션별 내용 작성 폼
  Widget _buildSectionForm(DailyReportState state) {
    final sections = _createdReport!.sections.toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    return Column(
      children: [
        // Report info header
        Container(
          width: double.infinity,
          color: AppColors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              Text(
                DateFormat('yyyy-MM-dd').format(_selectedDate),
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.accentBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _selectedPeriod == 'lunch' ? 'Lunch' : 'Dinner',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.accent,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _selectedStore?.name ?? '',
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.textSecondary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        // Section forms
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: sections.length,
            itemBuilder: (_, i) {
              final section = sections[i];
              // 템플릿에서 description 찾기
              String? description;
              if (_template != null) {
                final tSection = _template!.sections.where(
                  (ts) => ts.id == section.templateSectionId,
                );
                if (tSection.isNotEmpty) {
                  description = tSection.first.description;
                }
              }

              return Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      section.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _sectionControllers[section.id],
                      maxLines: 5,
                      minLines: 3,
                      style: const TextStyle(
                          fontSize: 14, color: AppColors.text),
                      decoration: InputDecoration(
                        hintText: description ?? 'Enter content...',
                        hintStyle: const TextStyle(
                            color: AppColors.textMuted, fontSize: 14),
                        alignLabelWithHint: true,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        // Action buttons
        SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            color: AppColors.white,
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: state.isLoading ? null : _saveDraft,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.border),
                      padding: const EdgeInsets.symmetric(vertical: 14),
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
                    onPressed: state.isLoading ? null : _saveAndSubmit,
                    child: state.isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
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
}

/// 시간대 선택 칩 위젯
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
