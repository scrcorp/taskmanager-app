/// 이슈 리포트 작성 화면.
///
/// 매장 선택 → 폼 템플릿 fetch → 카테고리/심각도/title/description + 동적 custom fields.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:htm_core/htm_core.dart';

import '../../l10n/app_localizations.dart';
import '../../models/issue_report.dart';
import '../../providers/issue_report_provider.dart';
import '../../services/api_client.dart';
import '../../services/issue_report_service.dart';
import '../../utils/api_error_display.dart';
import '../../widgets/app_header.dart';
import 'issue_report_link_picker.dart';
import 'issue_report_recipients_picker.dart';

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

  /// 마지막으로 클라가 description 에 집어넣은 프리셋 원문.
  /// 사용자가 손대지 않았는지 판단하는 유일한 기준이다.
  String? _lastPresetText;

  String _visibilityScope = IssueVisibilityScope.defaultScope;

  /// 자동 수신자 (그 매장에 배정된 GM 이상 전원). **해제 불가**.
  List<IssueRecipient> _autoRecipients = [];
  bool _loadingRecipients = false;
  String? _recipientsError;

  /// 콕 집어 추가한 사람 → payload.extra_viewers.user_ids
  final List<IssuePerson> _addedPeople = [];

  /// 선택한 조회 범위에서 실제로 보게 될 사람 (서버 예상 목록).
  IssueViewersPreview? _viewers;
  bool _loadingViewers = false;
  String? _viewersError;
  bool _viewersExpanded = false;

  /// 예상 목록 요청 순번 — 범위를 빠르게 바꿔도 늦게 온 응답이 덮어쓰지 않게.
  int _viewersReq = 0;

  /// 접힌 상태에서 보여줄 인원 수.
  static const int _viewersCollapsedCount = 3;

  /// 제출 실패 사유 (폼 인라인 표시).
  String? _submitError;

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
          _loadRecipients();
          _loadViewers();
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
      if (!mounted) return;
      setState(() {
        _template = t;
        _customValues.clear();
        _loadingTemplate = false;
      });
      _selectCategory(t.categories.isNotEmpty ? t.categories.first.code : null);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingTemplate = false);
    }
  }

  IssueCategoryDef? _categoryDef(String? code) {
    if (code == null) return null;
    for (final c in _template?.categories ?? const <IssueCategoryDef>[]) {
      if (c.code == code) return c;
    }
    return null;
  }

  /// 카테고리 선택 + description 프리필.
  ///
  /// 규칙: description 이 비어 있거나 **직전 프리셋 원문 그대로**일 때만 교체한다.
  /// 사용자가 손댄 흔적이 있으면 건드리지 않는다.
  void _selectCategory(String? code) {
    final nextPreset = _categoryDef(code)?.descriptionTemplate;
    final current = _descCtrl.text;
    final replaceable =
        current.trim().isEmpty || (_lastPresetText != null && current == _lastPresetText);
    setState(() {
      _category = code;
      if (replaceable) {
        _descCtrl.text = nextPreset ?? '';
        _descCtrl.selection =
            TextSelection.collapsed(offset: _descCtrl.text.length);
        _lastPresetText = nextPreset;
      }
    });
  }

  Future<void> _loadRecipients() async {
    final sid = _storeId;
    if (sid == null) return;
    setState(() {
      _loadingRecipients = true;
      _recipientsError = null;
    });
    try {
      final res = await ref
          .read(issueReportServiceProvider)
          .getIssueRecipients(storeId: sid);
      if (!mounted) return;
      setState(() {
        _autoRecipients = res.items.where((r) => !r.isAdded).toList();
        _loadingRecipients = false;
      });
    } catch (e) {
      if (!mounted) return;
      final t = AppL10n.of(context);
      setState(() {
        _autoRecipients = [];
        _loadingRecipients = false;
        _recipientsError = apiErrorTextOf(
          t,
          e,
          fallback: t.issueRecipientsLoadFailed,
        );
      });
    }
  }

  /// 선택한 범위에서 실제로 보게 될 사람 목록.
  ///
  /// store_all 은 인원이 많아 서버가 요약(listed=false)만 줄 수 있고,
  /// 그 경우 목록 대신 문구만 보여준다.
  Future<void> _loadViewers() async {
    final sid = _storeId;
    if (sid == null) return;
    final scope = _visibilityScope;
    final seq = ++_viewersReq;
    setState(() {
      _loadingViewers = true;
      _viewersError = null;
      _viewersExpanded = false;
    });
    try {
      final res = await ref.read(issueReportServiceProvider).getIssueViewers(
            storeId: sid,
            scope: scope,
          );
      if (!mounted || seq != _viewersReq) return;
      setState(() {
        _viewers = res;
        _loadingViewers = false;
      });
    } catch (e) {
      if (!mounted || seq != _viewersReq) return;
      final t = AppL10n.of(context);
      setState(() {
        _viewers = null;
        _loadingViewers = false;
        _viewersError = apiErrorTextOf(
          t,
          e,
          fallback: t.issueViewersPreviewLoadFailed,
        );
      });
    }
  }

  Future<void> _addRecipients() async {
    final sid = _storeId;
    if (sid == null) return;
    final exclude = <String>{
      ..._autoRecipients.map((r) => r.userId),
      ..._addedPeople.map((p) => p.id),
    };
    final picked = await showIssueRecipientPicker(
      context: context,
      ref: ref,
      storeId: sid,
      excludeIds: exclude,
    );
    if (picked == null || picked.isEmpty || !mounted) return;
    setState(() => _addedPeople.addAll(picked));
  }

  bool get _canSubmit =>
      _storeId != null &&
      _titleCtrl.text.trim().isNotEmpty &&
      _category != null &&
      !_submitting;

  Future<void> _submit() async {
    if (!_canSubmit) return;
    final t = AppL10n.of(context);
    setState(() {
      _submitting = true;
      _submitError = null;
    });
    try {
      final created = await ref.read(issueReportProvider.notifier).createReport(
            storeId: _storeId!,
            title: _titleCtrl.text.trim(),
            category: _category!,
            severity: _severity,
            description:
                _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
            customFieldValues: _customValues,
            extraViewerUserIds: _addedPeople.map((p) => p.id).toList(),
            visibilityScope: _visibilityScope,
            links: _links.toJson(),
          );
      if (!mounted) return;
      setState(() => _submitting = false);
      await AppModal.show(
        context,
        title: 'Submitted',
        message: 'Your issue has been reported.',
        type: ModalType.success,
      );
      if (mounted) {
        context.pushReplacement('/issue-reports/${created.id}');
      }
    } catch (e) {
      if (!mounted) return;
      // 사유 + 다음 행동은 폼 인라인에 남겨 둔다 (모달을 닫아도 사라지지 않도록).
      setState(() {
        _submitting = false;
        _submitError =
            apiErrorTextOf(t, e, fallback: t.issueSubmitFailedFallback);
      });
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
                          _textField(
                      _descCtrl,
                      hint: 'Details',
                      minLines: 5,
                      maxLines: null,
                    ),
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
                          const SizedBox(height: 16),
                          const Divider(),
                          const SizedBox(height: 8),
                          _visibilitySection(),
                          const SizedBox(height: 20),
                          _recipientsSection(),
                          if (_submitError != null) ...[
                            const SizedBox(height: 16),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.danger.withValues(alpha: 0.08),
                                border:
                                    Border.all(color: AppColors.danger),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    AppL10n.of(context).issueSubmitFailedTitle,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.danger,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _submitError!,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: AppColors.text,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
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
              // 수신자/조회자는 매장 종속이라 매장이 바뀌면 전부 리셋한다.
              _autoRecipients = [];
              _addedPeople.clear();
              _recipientsError = null;
              _viewers = null;
              _viewersError = null;
            });
            _loadTemplate();
            _loadRecipients();
            _loadViewers();
          },
        ),
      ),
    );
  }

  /// [maxLines] 를 null 로 주면 내용에 맞춰 칸이 통째로 늘어난다(내부 스크롤 없음).
  /// 여러 줄 입력에는 이 형태를 쓸 것 — 고정 maxLines 는 작은 창 안에 자체 스크롤을
  /// 만들고, 그게 바깥 페이지 스크롤과 겹쳐 모바일 웹에서 줄 선택/커서 이동을 먹는다.
  Widget _textField(
    TextEditingController c, {
    String? hint,
    int? maxLines = 1,
    int? minLines,
  }) {
    return TextField(
      controller: c,
      maxLines: maxLines,
      minLines: minLines,
      keyboardType: maxLines == 1 ? null : TextInputType.multiline,
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
          onChanged: _selectCategory,
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

  String _scopeLabel(AppL10n t, String scope) {
    switch (scope) {
      case IssueVisibilityScope.managers:
        return t.issueVisibilityManagers;
      case IssueVisibilityScope.storeAll:
        return t.issueVisibilityStoreAll;
      default:
        return t.issueVisibilityDefault;
    }
  }

  Widget _sectionTitle(String text) => Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
        ),
      );

  Widget _sectionHelp(String text) => Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 8),
        child: Text(
          text,
          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
      );

  Widget _visibilitySection() {
    final t = AppL10n.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(t.issueVisibilitySectionTitle),
        _sectionHelp(t.issueVisibilityHelp),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AppColors.white,
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(10),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _visibilityScope,
              isExpanded: true,
              items: IssueVisibilityScope.all
                  .map((s) => DropdownMenuItem<String>(
                        value: s,
                        child: Text(
                          _scopeLabel(t, s),
                          style: const TextStyle(fontSize: 14),
                        ),
                      ))
                  .toList(),
              onChanged: (v) {
                setState(
                  () =>
                      _visibilityScope = v ?? IssueVisibilityScope.defaultScope,
                );
                // 범위를 바꾸면 예상 목록은 즉시 다시 계산한다.
                _loadViewers();
              },
            ),
          ),
        ),
        const SizedBox(height: 12),
        _viewersPreview(),
      ],
    );
  }

  /// 지금 고른 범위에서 실제로 보게 될 사람들.
  ///
  /// 세로를 아끼려고 기본은 상위 [_viewersCollapsedCount] 명 + "and N more",
  /// 탭하면 전체가 펼쳐진다. store_all 은 목록 없이 요약 문구만.
  Widget _viewersPreview() {
    final t = AppL10n.of(context);
    final v = _viewers;
    final people = _previewPeople();

    // 목록/요약은 **서버 응답(mode)** 이 정한다. 고른 scope 로 미리 단정하면
    // store_all 요청이 실패했을 때 에러 대신 "Everyone assigned to this store"
    // 를 자신 있게 보여주는 조용한 실패가 된다.
    final summaryMode = v != null && !v.listed;

    Widget body;
    if (_storeId == null) {
      return const SizedBox.shrink();
    } else if (_loadingViewers || (v == null && _viewersError == null)) {
      body = const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    } else if (_viewersError != null) {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _viewersError!,
            style: const TextStyle(fontSize: 12, color: AppColors.danger),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: _loadViewers,
              child: Text(t.actionRetry),
            ),
          ),
        ],
      );
    } else if (summaryMode) {
      // C1: 인원이 많아 목록을 만들지 않는다 — 요약 문구만.
      body = Text(
        t.issueViewersPreviewStoreAll,
        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
      );
    } else if (people.isEmpty) {
      body = Text(
        t.issueViewersPreviewEmpty,
        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
      );
    } else {
      final showAll = _viewersExpanded || people.length <= _viewersCollapsedCount;
      final visible =
          showAll ? people : people.take(_viewersCollapsedCount).toList();
      final hidden = people.length - visible.length;
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...visible.map(_viewerRow),
          if (hidden > 0 || _viewersExpanded)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () =>
                    setState(() => _viewersExpanded = !_viewersExpanded),
                child: Text(
                  _viewersExpanded
                      ? t.issueViewersShowLess
                      : t.issueViewersMore(hidden),
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ),
        ],
      );
    }

    // 못 불러온 상태에서 "0 people" 같은 거짓 숫자를 찍지 않는다.
    final count = (v == null || _viewersError != null)
        ? null
        : (summaryMode ? v.totalCount : people.length);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  t.issueViewersPreviewTitle,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              if (count != null && !_loadingViewers)
                Text(
                  t.issueViewersPreviewCount(count),
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          body,
        ],
      ),
    );
  }

  /// 서버 예상 목록 + 이 화면에서 추가한 사람(아직 저장 전이라 서버는 모른다).
  List<({String id, String name, String roleLabel, String reason})>
      _previewPeople() {
    final t = AppL10n.of(context);
    final out = <({String id, String name, String roleLabel, String reason})>[];
    final seen = <String>{};

    // 서버 reason 코드 → 현지화 문구. 모르는 코드는 아무 말이나 찍지 않고
    // 서버가 같이 준 reason_label(영어 원문)을 그대로 쓴다. 그것도 없으면 생략.
    String reasonOf(IssueViewer v) {
      switch (v.reason) {
        case 'added':
          return t.issueViewerReasonAdded;
        case 'author':
          return t.issueViewerReasonAuthor;
        case 'gm_or_above':
          return t.issueViewerReasonGmOrAbove;
        case 'store_manager':
          return t.issueViewerReasonManager;
        case 'store':
          return t.issueViewerReasonStore;
        default:
          return v.reasonLabel;
      }
    }

    final v = _viewers;
    if (v != null && v.listed) {
      for (final item in v.items) {
        if (!seen.add(item.userId)) continue;
        out.add((
          id: item.userId,
          name: item.fullName,
          roleLabel: item.roleLabel,
          reason: reasonOf(item),
        ));
      }
    }
    for (final p in _addedPeople) {
      if (!seen.add(p.id)) continue;
      out.add((
        id: p.id,
        name: p.name,
        roleLabel: p.roleLabel,
        reason: t.issueViewerReasonAdded,
      ));
    }
    return out;
  }

  Widget _viewerRow(
      ({String id, String name, String roleLabel, String reason}) p) {
    final t = AppL10n.of(context);
    // reason 이 비면(모르는 서버 코드 + reason_label 없음) 구분자만 남지 않게 뺀다.
    final sub = [
      if (p.roleLabel.isNotEmpty) roleDisplayLabel(t, p.roleLabel),
      if (p.reason.isNotEmpty) p.reason,
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(Icons.visibility_outlined,
                size: 14, color: AppColors.textSecondary),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.name,
                  style: const TextStyle(fontSize: 13, color: AppColors.text),
                ),
                if (sub.isNotEmpty)
                  Text(
                    sub,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _recipientsSection() {
    final t = AppL10n.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(t.issueRecipientsTitle),
        _sectionHelp(t.issueRecipientsHelp),
        if (_loadingRecipients)
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
        else ...[
          if (_recipientsError != null) ...[
            Text(
              _recipientsError!,
              style: const TextStyle(fontSize: 12, color: AppColors.danger),
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: _loadRecipients,
                child: Text(t.actionRetry),
              ),
            ),
          ] else if (_autoRecipients.isEmpty && _addedPeople.isEmpty)
            Text(
              t.issueRecipientsEmpty,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          // 자동 수신자(매장 GM+)는 해제 불가 — 잠긴 칩으로만 보여주고
          // 체크박스나 X 같은 해제 제스처를 아예 노출하지 않는다.
          if (_autoRecipients.isNotEmpty)
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _autoRecipients
                  .map((r) => _lockedRecipientChip(t, r))
                  .toList(),
            ),
          if (_autoRecipients.isNotEmpty && _addedPeople.isNotEmpty)
            const SizedBox(height: 8),
          ..._addedPeople.map((p) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    const Icon(Icons.person_add_alt,
                        size: 16, color: AppColors.accent),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p.name,
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.text,
                            ),
                          ),
                          if (p.roleLabel.isNotEmpty)
                            Text(
                              '${roleDisplayLabel(t, p.roleLabel)} · ${t.issueRecipientsAddedBadge}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      color: AppColors.textSecondary,
                      onPressed: () =>
                          setState(() => _addedPeople.remove(p)),
                    ),
                  ],
                ),
              )),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: _storeId == null ? null : _addRecipients,
              icon: const Icon(Icons.add, size: 16),
              label: Text(t.issueRecipientsAddPeople),
            ),
          ),
        ],
      ],
    );
  }

  /// 해제 불가 자동 수신자 칩. 자물쇠 + "Always notified" 배지로
  /// 왜 뺄 수 없는지 알 수 있게 한다.
  Widget _lockedRecipientChip(AppL10n t, IssueRecipient r) {
    final role = r.roleLabel.isEmpty ? '' : ' · ${roleDisplayLabel(t, r.roleLabel)}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.bg,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.lock_outline, size: 13, color: AppColors.textSecondary),
          const SizedBox(width: 5),
          Text(
            '${r.fullName}$role',
            style: const TextStyle(fontSize: 12, color: AppColors.text),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: AppColors.textSecondary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              t.issueRecipientsAlwaysBadge,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
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
              // 내용에 맞춰 자라게 — 고정 maxLines 는 내부 스크롤을 만든다(_textField 주석 참조).
              minLines: 3,
              maxLines: null,
              keyboardType: TextInputType.multiline,
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
