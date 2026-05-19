/// 이슈 리포트 작성 화면.
///
/// 매장 선택 → 폼 템플릿 fetch → 카테고리/심각도/title/description + 동적 custom fields.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:htm_core/htm_core.dart';

import '../../models/issue_report.dart';
import '../../providers/issue_report_provider.dart';
import '../../services/api_client.dart';
import '../../services/issue_report_service.dart';
import '../../widgets/app_header.dart';
import 'issue_report_link_picker.dart';

class IssueReportCreateScreen extends ConsumerStatefulWidget {
  const IssueReportCreateScreen({super.key});

  @override
  ConsumerState<IssueReportCreateScreen> createState() =>
      _IssueReportCreateScreenState();
}

class _IssueReportCreateScreenState
    extends ConsumerState<IssueReportCreateScreen> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final Map<String, dynamic> _customValues = {};

  String? _storeId;
  IssueReportTemplate? _template;
  String? _category;
  String _severity = 'medium';
  List<Map<String, dynamic>> _stores = [];
  bool _loadingStores = true;
  bool _loadingTemplate = false;
  bool _submitting = false;
  LinkValues _links = const LinkValues();

  @override
  void initState() {
    super.initState();
    _loadStores();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadStores() async {
    try {
      final res = await ref.read(dioProvider).get('/app/my/stores');
      final list = (res.data as List).cast<Map<String, dynamic>>();
      setState(() {
        _stores = list;
        _loadingStores = false;
        if (list.length == 1) {
          _storeId = list[0]['id'];
          _loadTemplate();
        }
      });
    } catch (_) {
      setState(() => _loadingStores = false);
    }
  }

  Future<void> _loadTemplate() async {
    if (_storeId == null) return;
    setState(() => _loadingTemplate = true);
    try {
      final t = await ref
          .read(issueReportServiceProvider)
          .getTemplate(storeId: _storeId);
      setState(() {
        _template = t;
        _category = t.categories.isNotEmpty ? t.categories.first.code : null;
        _customValues.clear();
        _loadingTemplate = false;
      });
    } catch (e) {
      setState(() => _loadingTemplate = false);
    }
  }

  bool get _canSubmit =>
      _storeId != null &&
      _titleCtrl.text.trim().isNotEmpty &&
      _category != null &&
      !_submitting;

  Future<void> _submit() async {
    if (!_canSubmit) return;
    setState(() => _submitting = true);
    final created =
        await ref.read(issueReportProvider.notifier).createReport(
              storeId: _storeId!,
              title: _titleCtrl.text.trim(),
              category: _category!,
              severity: _severity,
              description: _descCtrl.text.trim().isEmpty
                  ? null
                  : _descCtrl.text.trim(),
              customFieldValues: _customValues,
              links: _links.toJson(),
            );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (created != null) {
      await AppModal.show(
        context,
        title: 'Submitted',
        message: 'Your issue has been reported.',
        type: ModalType.success,
      );
      if (mounted) {
        context.pushReplacement('/issue-reports/${created.id}');
      }
    } else {
      await AppModal.show(
        context,
        title: 'Submission failed',
        message: 'Please try again.',
        type: ModalType.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            AppHeader(
              title: 'New Issue',
              isDetail: true,
              onBack: () => context.pop(),
            ),
            Expanded(
              child: _loadingStores
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _label('Store *'),
                          _storeDropdown(),
                          const SizedBox(height: 16),
                          _label('Title *'),
                          _textField(_titleCtrl, hint: 'Short summary'),
                          const SizedBox(height: 16),
                          if (_loadingTemplate)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: Center(
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              ),
                            )
                          else if (_template != null) ...[
                            _label('Category *'),
                            _categoryDropdown(),
                            const SizedBox(height: 16),
                          ],
                          _label('Severity *'),
                          _severityDropdown(),
                          const SizedBox(height: 16),
                          _label('Description'),
                          _textField(_descCtrl, hint: 'Details', maxLines: 5),
                          if (_template != null &&
                              _template!.customFields.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            const Divider(),
                            const SizedBox(height: 8),
                            const Text(
                              'Store fields',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ..._template!.customFields.map(_customFieldWidget),
                          ],
                          const SizedBox(height: 16),
                          const Divider(),
                          const SizedBox(height: 8),
                          const Text(
                            'Related items',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Optional — link schedules, checklists, positions, '
                            'work roles, or people related to this issue.',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          IssueReportLinkPicker(
                            storeId: _storeId,
                            value: _links,
                            onChanged: (v) => setState(() => _links = v),
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _canSubmit ? _submit : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.accent,
                                foregroundColor: AppColors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: Text(_submitting ? 'Submitting…' : 'Submit'),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      );

  Widget _storeDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _storeId,
          isExpanded: true,
          hint: const Text('Select a store…'),
          items: _stores
              .map((s) => DropdownMenuItem<String>(
                    value: s['id'] as String,
                    child: Text(s['name'] as String),
                  ))
              .toList(),
          onChanged: (v) {
            if (v == null) return;
            setState(() {
              _storeId = v;
              _category = null;
              _template = null;
              _customValues.clear();
              _links = const LinkValues();
            });
            _loadTemplate();
          },
        ),
      ),
    );
  }

  Widget _textField(TextEditingController c, {String? hint, int maxLines = 1}) {
    return TextField(
      controller: c,
      maxLines: maxLines,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: AppColors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border),
        ),
      ),
      onChanged: (_) => setState(() {}),
    );
  }

  Widget _categoryDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _category,
          isExpanded: true,
          items: _template!.categories
              .where((c) => c.isActive)
              .map((c) => DropdownMenuItem<String>(
                    value: c.code,
                    child: Text(c.label),
                  ))
              .toList(),
          onChanged: (v) => setState(() => _category = v),
        ),
      ),
    );
  }

  Widget _severityDropdown() {
    const opts = ['low', 'medium', 'high', 'critical'];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _severity,
          isExpanded: true,
          items: opts
              .map((s) => DropdownMenuItem<String>(
                    value: s,
                    child: Text(s),
                  ))
              .toList(),
          onChanged: (v) => setState(() => _severity = v ?? 'medium'),
        ),
      ),
    );
  }

  Widget _customFieldWidget(IssueCustomFieldDef f) {
    final current = _customValues[f.id];
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label('${f.label}${f.required ? ' *' : ''}'),
          if (f.type == 'short_text')
            TextField(
              decoration: InputDecoration(
                hintText: f.placeholder,
                filled: true,
                fillColor: AppColors.white,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              maxLength: f.maxLength,
              onChanged: (v) => _customValues[f.id] = v,
            )
          else if (f.type == 'long_text')
            TextField(
              decoration: InputDecoration(
                hintText: f.placeholder,
                filled: true,
                fillColor: AppColors.white,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              maxLines: 3,
              maxLength: f.maxLength,
              onChanged: (v) => _customValues[f.id] = v,
            )
          else if (f.type == 'number')
            TextField(
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: f.placeholder,
                filled: true,
                fillColor: AppColors.white,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onChanged: (v) =>
                  _customValues[f.id] = v.isEmpty ? null : num.tryParse(v),
            )
          else if (f.type == 'single_choice')
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: AppColors.white,
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(10),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: current as String?,
                  isExpanded: true,
                  hint: const Text('Select…'),
                  items: (f.options ?? [])
                      .map((o) => DropdownMenuItem<String>(
                            value: o,
                            child: Text(o),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _customValues[f.id] = v),
                ),
              ),
            )
          else if (f.type == 'multi_choice')
            Wrap(
              spacing: 6,
              children: (f.options ?? []).map((o) {
                final arr = (current as List?)?.cast<String>() ?? [];
                final on = arr.contains(o);
                return FilterChip(
                  label: Text(o),
                  selected: on,
                  onSelected: (v) {
                    final newArr = [...arr];
                    if (v) {
                      newArr.add(o);
                    } else {
                      newArr.remove(o);
                    }
                    setState(() => _customValues[f.id] = newArr);
                  },
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}
