/// Schedule request tab (fullscreen overlay)
///
/// Weekly request editing. Per-day summary/detail/form 3-panel UI.
/// States: empty → added → submitted → updated / deleted
/// Multi-week: changes persist across week switches, submitted all at once.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/theme.dart';
import '../../models/schedule.dart';
import '../../providers/schedule_provider.dart';
import '../../services/schedule_service.dart';

const _weekdayLabels = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

/// Per-day request data (local editing)
class _ReqDay {
  String storeId;
  String workRoleId;
  String start;
  String end;
  String note;
  String? existingId;
  bool isDeleted;

  _ReqDay({
    this.storeId = '',
    this.workRoleId = '',
    this.start = '',
    this.end = '',
    this.note = '',
    this.existingId,
    this.isDeleted = false,
  });

  _ReqDay copy() => _ReqDay(
        storeId: storeId,
        workRoleId: workRoleId,
        start: start,
        end: end,
        note: note,
        existingId: existingId,
        isDeleted: isDeleted,
      );

  bool get isEmpty => storeId.isEmpty && workRoleId.isEmpty;
  bool get isComplete =>
      storeId.isNotEmpty &&
      workRoleId.isNotEmpty &&
      start.isNotEmpty &&
      end.isNotEmpty;
}

class ScheduleRequestTab extends ConsumerStatefulWidget {
  final DateTime? targetDate;
  const ScheduleRequestTab({super.key, this.targetDate});

  @override
  ConsumerState<ScheduleRequestTab> createState() =>
      _ScheduleRequestTabState();
}

class _ScheduleRequestTabState extends ConsumerState<ScheduleRequestTab> {
  late DateTime _weekStart;
  // All data across all weeks (keyed by date string)
  final Map<String, _ReqDay> _data = {};
  final Map<String, _ReqDay> _originals = {};
  final Map<String, String> _viewMode = {};
  // Track which weeks have been loaded from API
  final Set<String> _loadedWeeks = {};
  bool _isSubmitting = false;
  String? _lastAppliedTemplateId;
  // 폼 편집 중 임시 데이터 (Save 전까지 _data에 반영하지 않음)
  final Map<String, _ReqDay> _formEdits = {};

  @override
  void initState() {
    super.initState();
    if (widget.targetDate != null) {
      final d = widget.targetDate!;
      final daysSinceSunday = d.weekday % 7;
      _weekStart = DateTime(d.year, d.month, d.day)
          .subtract(Duration(days: daysSinceSunday));
    } else {
      final now = DateTime.now();
      final daysSinceSunday = now.weekday % 7;
      _weekStart = DateTime(now.year, now.month, now.day)
          .add(Duration(days: 7 - daysSinceSunday));
    }
    _ensureWeekLoaded(_weekStart);
  }

  List<DateTime> get _weekDays =>
      List.generate(7, (i) => _weekStart.add(Duration(days: i)));

  ScheduleService get _service => ref.read(scheduleServiceProvider);

  List<Map<String, dynamic>> get _stores =>
      ref.read(scheduleProvider).stores;

  List<WorkRole> get _workRoles => ref.read(scheduleProvider).workRoles;

  /// Load a week's requests from API (only if not already loaded)
  Future<void> _ensureWeekLoaded(DateTime weekStart) async {
    final key = _fmt(weekStart);
    if (_loadedWeeks.contains(key)) {
      if (mounted) setState(() {});
      return;
    }

    final dateFrom = _fmt(weekStart);
    final dateTo = _fmt(weekStart.add(const Duration(days: 6)));
    try {
      final requests =
          await _service.getMyRequests(dateFrom: dateFrom, dateTo: dateTo);
      for (final r in requests) {
        if (r.status == 'rejected') continue;
        final ds = _fmt(r.workDate);
        // Don't overwrite local changes
        if (_data.containsKey(ds)) continue;
        final rd = _ReqDay(
          storeId: r.storeId,
          workRoleId: r.workRoleId ?? '',
          start: r.preferredStartTime ?? '',
          end: r.preferredEndTime ?? '',
          note: r.note ?? '',
          existingId: r.id,
        );
        _data[ds] = rd;
        _originals[ds] = rd.copy();
      }
      _loadedWeeks.add(key);
      if (mounted) setState(() {});
    } catch (_) {}
  }

  String _status(String ds) {
    final d = _data[ds];
    if (d == null || d.isEmpty || !d.isComplete) return 'empty';
    if (d.isDeleted) return 'deleted';
    if (d.existingId == null) return 'added';
    final orig = _originals[ds];
    if (orig != null &&
        (d.storeId != orig.storeId ||
            d.workRoleId != orig.workRoleId ||
            d.start != orig.start ||
            d.end != orig.end)) {
      return 'updated';
    }
    return 'submitted';
  }

  bool get _hasChanges {
    for (final ds in _data.keys) {
      final s = _status(ds);
      if (s == 'added' || s == 'updated' || s == 'deleted') return true;
    }
    return false;
  }

  bool get _hasOpenForms {
    for (final ds in _viewMode.keys) {
      if (_viewMode[ds] == 'form') return true;
    }
    return false;
  }

  /// Count total changes across all weeks
  int get _changeCount {
    int count = 0;
    for (final ds in _data.keys) {
      final s = _status(ds);
      if (s == 'added' || s == 'updated' || s == 'deleted') count++;
    }
    return count;
  }

  void _prevWeek() {
    _weekStart = _weekStart.subtract(const Duration(days: 7));
    _ensureWeekLoaded(_weekStart);
  }

  void _nextWeek() {
    _weekStart = _weekStart.add(const Duration(days: 7));
    _ensureWeekLoaded(_weekStart);
  }

  @override
  Widget build(BuildContext context) {
    final weekEnd = _weekStart.add(const Duration(days: 6));
    final filledCount = _weekDays.where((d) {
      final ds = _fmt(d);
      final data = _data[ds];
      return data != null && !data.isDeleted && !data.isEmpty;
    }).length;
    final totalChanges = _changeCount;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Schedule Request'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Week navigation
          Container(
            color: AppColors.white,
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: _prevWeek,
                  child: const Icon(Icons.chevron_left,
                      color: AppColors.textSecondary),
                ),
                const SizedBox(width: 12),
                Text(
                  '${_weekStart.month}/${_weekStart.day} - ${weekEnd.month}/${weekEnd.day}',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: _nextWeek,
                  child: const Icon(Icons.chevron_right,
                      color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          // Template/Copy buttons
          Container(
            color: AppColors.white,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Row(
              children: [
                _chipButton(Icons.content_copy, 'Copy Last Week', _copyLastWeek),
                const SizedBox(width: 8),
                _chipButton(
                    Icons.view_list_outlined, 'Template', _showTemplateModal),
              ],
            ),
          ),
          // Day rows
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: 7,
              itemBuilder: (_, i) => _buildDayRow(_weekDays[i]),
            ),
          ),
          // Footer: summary + submit
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            decoration: const BoxDecoration(
              color: AppColors.white,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    totalChanges > 0
                        ? '$filledCount day${filledCount != 1 ? 's' : ''} scheduled · $totalChanges change${totalChanges != 1 ? 's' : ''}'
                        : '$filledCount day${filledCount != 1 ? 's' : ''} scheduled',
                    style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500),
                  ),
                ),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _hasChanges && !_isSubmitting ? _showSubmitConfirmation : null,
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: AppColors.white))
                        : Text(totalChanges > 0
                            ? 'Submit ($totalChanges)'
                            : 'Submit'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chipButton(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border, width: 1.5),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: AppColors.textSecondary),
            const SizedBox(width: 6),
            Text(label,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }

  // ────── Day Row ──────

  Widget _buildDayRow(DateTime date) {
    final ds = _fmt(date);
    final status = _status(ds);
    final dow = date.weekday % 7;
    final mode = _viewMode[ds] ?? 'summary';
    final data = _data[ds];

    // Badge
    String badgeText;
    Color badgeColor;
    Color badgeBg;
    switch (status) {
      case 'added':
        badgeText = 'Added';
        badgeColor = AppColors.accent;
        badgeBg = AppColors.accentBg;
        break;
      case 'submitted':
        badgeText = 'Submitted';
        badgeColor = AppColors.accent;
        badgeBg = AppColors.accentBg;
        break;
      case 'updated':
        badgeText = 'Updated';
        badgeColor = AppColors.warning;
        badgeBg = AppColors.warningBg;
        break;
      case 'deleted':
        badgeText = 'Deleted';
        badgeColor = AppColors.danger;
        badgeBg = AppColors.dangerBg;
        break;
      default:
        badgeText = 'Empty';
        badgeColor = AppColors.textMuted;
        badgeBg = AppColors.bg;
    }

    // Icon buttons per status
    List<Widget> icons = [];
    switch (status) {
      case 'empty':
        icons = [_iconBtn(Icons.edit_outlined, AppColors.textSecondary, () => _openForm(ds))];
        break;
      case 'added':
      case 'submitted':
        icons = [
          _iconBtn(Icons.edit_outlined, AppColors.textSecondary, () => _openForm(ds)),
          _iconBtn(Icons.delete_outline, AppColors.danger, () => _deleteDay(ds)),
        ];
        break;
      case 'updated':
        icons = [
          _iconBtn(Icons.undo, AppColors.accent, () => _revertDay(ds)),
          _iconBtn(Icons.edit_outlined, AppColors.textSecondary, () => _openForm(ds)),
          _iconBtn(Icons.delete_outline, AppColors.danger, () => _deleteDay(ds)),
        ];
        break;
      case 'deleted':
        icons = [
          _iconBtn(Icons.edit_outlined, AppColors.textSecondary, () => _openForm(ds)),
          _iconBtn(Icons.undo, AppColors.accent, () => _revertDay(ds)),
        ];
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header: date + badge + icons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Text('${date.day}',
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700)),
                const SizedBox(width: 4),
                Text(_weekdayLabels[dow],
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textMuted)),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                      color: badgeBg,
                      borderRadius: BorderRadius.circular(999)),
                  child: Text(badgeText,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: badgeColor)),
                ),
                const Spacer(),
                ...icons,
              ],
            ),
          ),
          // Body: summary / detail / form
          if (_hasVisibleData(status, data) || mode == 'form')
            Container(
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: mode == 'form'
                  ? _buildForm(ds, date, _formEdits[ds])
                  : mode == 'detail'
                      ? _buildDetail(ds, data!)
                      : _buildSummary(ds, data!),
            ),
        ],
      ),
    );
  }

  bool _hasVisibleData(String status, _ReqDay? data) {
    return (status == 'added' ||
            status == 'submitted' ||
            status == 'updated') &&
        data != null &&
        !data.isEmpty;
  }

  Widget _iconBtn(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        margin: const EdgeInsets.only(left: 4),
        decoration: BoxDecoration(
          color: AppColors.bg,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 16, color: color),
      ),
    );
  }

  // ────── Summary View ──────

  Widget _buildSummary(String ds, _ReqDay data) {
    final store = _stores.firstWhere(
        (s) => s['id'] == data.storeId,
        orElse: () => {'name': ''});
    final wr = _workRoles
        .where((w) => w.id == data.workRoleId)
        .firstOrNull;
    final text =
        '${store['name']} · ${wr?.displayName ?? ''} · ${_trimT(data.start)}-${_trimT(data.end)}';

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _viewMode[ds] = 'detail'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Text(text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontSize: 13, color: AppColors.textSecondary)),
      ),
    );
  }

  // ────── Detail View ──────

  Widget _buildDetail(String ds, _ReqDay data) {
    final store = _stores.firstWhere(
        (s) => s['id'] == data.storeId,
        orElse: () => {'name': ''});
    final wr = _workRoles
        .where((w) => w.id == data.workRoleId)
        .firstOrNull;
    final status = _status(ds);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _viewMode[ds] = 'summary'),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            _detailRow('Store', store['name'] ?? ''),
            _detailRow('Role', wr?.displayName ?? ''),
            _detailRow('Time',
                '${_trimT(data.start)} - ${_trimT(data.end)}'),
            if (status == 'updated') ...[
              const SizedBox(height: 8),
              _buildCompare(ds, data),
            ],
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 13, color: AppColors.textMuted)),
          Text(value,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildCompare(String ds, _ReqDay current) {
    final orig = _originals[ds];
    if (orig == null) return const SizedBox.shrink();
    final origStore = _stores.firstWhere(
        (s) => s['id'] == orig.storeId,
        orElse: () => {'name': ''});
    final origWr =
        _workRoles.where((w) => w.id == orig.workRoleId).firstOrNull;
    final curStore = _stores.firstWhere(
        (s) => s['id'] == current.storeId,
        orElse: () => {'name': ''});
    final curWr =
        _workRoles.where((w) => w.id == current.workRoleId).firstOrNull;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
          color: AppColors.bg, borderRadius: BorderRadius.circular(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Changes',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
                child: _cmpItem('Original',
                    '${origStore['name']}\n${origWr?.displayName ?? ''}\n${_trimT(orig.start)}-${_trimT(orig.end)}',
                    AppColors.white)),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child:
                  Icon(Icons.arrow_forward, size: 14, color: AppColors.textMuted),
            ),
            Expanded(
                child: _cmpItem('Modified',
                    '${curStore['name']}\n${curWr?.displayName ?? ''}\n${_trimT(current.start)}-${_trimT(current.end)}',
                    AppColors.warningBg)),
          ]),
        ],
      ),
    );
  }

  Widget _cmpItem(String label, String value, Color bg) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Column(children: [
        Text(label,
            style:
                const TextStyle(fontSize: 11, color: AppColors.textMuted)),
        const SizedBox(height: 4),
        Text(value,
            textAlign: TextAlign.center,
            style:
                const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      ]),
    );
  }

  // ────── Form View ──────

  Widget _buildForm(String ds, DateTime date, _ReqDay? editData) {
    final edit = editData ?? _ReqDay();
    final storeId = edit.storeId;
    final workRoleId = edit.workRoleId;
    final start = edit.start;
    final end = edit.end;
    // existingId는 _data[ds]에서 확인 (edit copy에는 없을 수 있음)
    final isNew = _data[ds]?.existingId == null;

    final filteredRoles = storeId.isNotEmpty
        ? _workRoles.where((w) => w.storeId == storeId).toList()
        : <WorkRole>[];

    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Store
          const Text('Store',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary)),
          const SizedBox(height: 6),
          _buildDropdown<String>(
            value: storeId.isNotEmpty ? storeId : null,
            hint: 'Select store',
            items: _stores
                .map((s) => DropdownMenuItem(
                    value: s['id'] as String,
                    child: Text(s['name'] as String)))
                .toList(),
            onChanged: (v) {
              if (v == null) return;
              edit.storeId = v;
              edit.workRoleId = '';
              final roles =
                  _workRoles.where((w) => w.storeId == v).toList();
              if (roles.length == 1) {
                edit.workRoleId = roles.first.id;
                edit.start = roles.first.defaultStartTime ?? '';
                edit.end = roles.first.defaultEndTime ?? '';
              }
              setState(() {});
            },
          ),
          const SizedBox(height: 10),
          // Work Role
          const Text('Work Role',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary)),
          const SizedBox(height: 6),
          _buildDropdown<String>(
            value: workRoleId.isNotEmpty &&
                    filteredRoles.any((w) => w.id == workRoleId)
                ? workRoleId
                : null,
            hint: storeId.isEmpty ? 'Select store first' : 'Select work role',
            items: filteredRoles
                .map((w) => DropdownMenuItem(
                    value: w.id, child: Text(w.displayName)))
                .toList(),
            onChanged: filteredRoles.isEmpty ? null : (v) {
              if (v == null) return;
              edit.workRoleId = v;
              final wr = _workRoles.firstWhere((w) => w.id == v);
              if (edit.start.isEmpty) edit.start = wr.defaultStartTime ?? '';
              if (edit.end.isEmpty) edit.end = wr.defaultEndTime ?? '';
              setState(() {});
            },
          ),
          const SizedBox(height: 10),
          // Time
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Start',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary)),
                    const SizedBox(height: 6),
                    _timeField(start, (v) {
                      edit.start = v;
                      setState(() {});
                    }),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('End',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary)),
                    const SizedBox(height: 6),
                    _timeField(end, (v) {
                      edit.end = v;
                      setState(() {});
                    }),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () {
                  _formEdits.remove(ds);
                  setState(() => _viewMode[ds] = 'summary');
                },
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () => _saveDay(ds, isNew),
                style: ElevatedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                ),
                child: Text(isNew ? 'Save' : 'Update'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown<T>({
    required T? value,
    required String hint,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?>? onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border, width: 1.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButton<T>(
        value: value,
        hint: Text(hint, style: const TextStyle(color: AppColors.textMuted, fontSize: 14)),
        isExpanded: true,
        underline: const SizedBox.shrink(),
        items: items,
        onChanged: onChanged,
      ),
    );
  }

  Widget _timeField(String value, ValueChanged<String> onChanged) {
    return GestureDetector(
      onTap: () async {
        final parts = value.isNotEmpty ? value.split(':') : ['9', '0'];
        final initial = TimeOfDay(
          hour: int.tryParse(parts[0]) ?? 9,
          minute: int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0,
        );
        final picked = await showTimePicker(
          context: context,
          initialTime: initial,
        );
        if (picked != null) {
          onChanged(
              '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}');
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.white,
          border: Border.all(color: AppColors.border, width: 1.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                value.isNotEmpty ? _trimT(value) : '--:--',
                style: TextStyle(
                  fontSize: 14,
                  color: value.isNotEmpty
                      ? AppColors.text
                      : AppColors.textMuted,
                ),
              ),
            ),
            const Icon(Icons.access_time,
                size: 16, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }

  // ────── Actions ──────

  void _openForm(String ds) {
    // 기존 데이터가 있으면 복사, 없으면 빈 데이터로 시작
    final existing = _data[ds];
    _formEdits[ds] = existing?.copy() ?? _ReqDay();
    setState(() => _viewMode[ds] = 'form');
  }

  void _saveDay(String ds, bool isNew) {
    final edit = _formEdits[ds];
    if (edit == null || !edit.isComplete) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }
    // 기존 existingId 보존
    final existingId = _data[ds]?.existingId;
    edit.existingId = existingId;
    edit.isDeleted = false;
    _data[ds] = edit;
    _formEdits.remove(ds);
    setState(() => _viewMode[ds] = 'detail');
  }

  void _deleteDay(String ds) {
    final d = _data[ds];
    if (d == null) return;
    if (d.existingId != null) {
      d.isDeleted = true;
    } else {
      _data.remove(ds);
    }
    setState(() => _viewMode[ds] = 'summary');
  }

  void _revertDay(String ds) {
    final orig = _originals[ds];
    if (orig != null) {
      _data[ds] = orig.copy();
    } else {
      _data.remove(ds);
    }
    setState(() => _viewMode[ds] = 'summary');
  }

  Future<void> _copyLastWeek() async {
    final lastWeekStart = _weekStart.subtract(const Duration(days: 7));

    // Ensure last week's data is loaded
    await _ensureWeekLoaded(lastWeekStart);

    // Also check entries from provider state for confirmed schedules
    final providerState = ref.read(scheduleProvider);

    int copied = 0;
    for (int i = 0; i < 7; i++) {
      final srcDate = lastWeekStart.add(Duration(days: i));
      final tgtDate = _weekStart.add(Duration(days: i));
      final srcDs = _fmt(srcDate);
      final tgtDs = _fmt(tgtDate);

      // Skip if target already has a non-deleted submitted request
      final existing = _data[tgtDs];
      if (existing != null && !existing.isDeleted && existing.existingId != null) continue;
      final preserveId = existing?.isDeleted == true ? existing?.existingId : null;

      // 1. Check _data first (local data from loaded weeks)
      final src = _data[srcDs];
      if (src != null && src.isDeleted) continue;
      if (src != null && src.isComplete) {
        _data[tgtDs] = _ReqDay(
          storeId: src.storeId,
          workRoleId: src.workRoleId,
          start: src.start,
          end: src.end,
          existingId: preserveId,
        );
        _viewMode[tgtDs] = 'detail';
        copied++;
        continue;
      }

      // 2. Try entries (confirmed schedules from provider)
      final entries = providerState.entries
          .where((e) => _fmt(e.workDate) == srcDs)
          .toList();
      if (entries.isNotEmpty) {
        final e = entries.first;
        final wr = _workRoles
            .where((w) => w.displayName == e.workRoleName && w.storeId == e.storeId)
            .firstOrNull;
        _data[tgtDs] = _ReqDay(
          storeId: e.storeId,
          workRoleId: wr?.id ?? '',
          start: e.startTime,
          end: entries.last.endTime,
          existingId: preserveId,
        );
        _viewMode[tgtDs] = 'detail';
        copied++;
        continue;
      }

      // 3. Try requests from provider (submitted, modified — skip rejected)
      final reqs = providerState.requests
          .where((r) => _fmt(r.workDate) == srcDs && r.status != 'rejected')
          .toList();
      if (reqs.isNotEmpty) {
        final req = reqs.first;
        _data[tgtDs] = _ReqDay(
          storeId: req.storeId,
          workRoleId: req.workRoleId ?? '',
          start: req.preferredStartTime ?? '',
          end: req.preferredEndTime ?? '',
          existingId: preserveId,
        );
        _viewMode[tgtDs] = 'detail';
        copied++;
      }
    }
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(copied > 0
            ? 'Copied $copied day${copied != 1 ? 's' : ''} from last week'
            : 'No schedule found for last week'),
      ),
    );
  }

  void _showTemplateModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TemplateSelectSheet(
        templates: ref.read(scheduleProvider).templates,
        weekdayLabels: _weekdayLabels,
        onApply: (t) {
          Navigator.of(context).pop();
          _applyTemplate(t);
        },
        onEdit: (t) {
          Navigator.of(context).pop();
          _showTemplateEditModal(t);
        },
        onCreate: () {
          Navigator.of(context).pop();
          _showTemplateEditModal(null);
        },
        onDelete: (t) async {
          await _service.deleteTemplate(t.id);
          await ref.read(scheduleProvider.notifier).refreshTemplates();
          if (mounted) {
            Navigator.of(context).pop();
            _showTemplateModal(); // reopen with updated list
          }
        },
      ),
    );
  }

  void _showTemplateEditModal(ScheduleTemplate? existing, {ScheduleTemplate? prefilled}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TemplateEditSheet(
        existing: existing,
        prefilled: prefilled,
        stores: _stores,
        workRoles: _workRoles,
        weekdayLabels: _weekdayLabels,
        onSave: (name, isDefault, items) async {
          if (existing != null) {
            await _service.updateTemplate(existing.id,
                name: name, isDefault: isDefault, items: items);
          } else {
            await _service.createTemplate(
                name: name, isDefault: isDefault, items: items);
          }
          await ref.read(scheduleProvider.notifier).refreshTemplates();
          if (mounted) {
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(existing != null ? 'Template updated' : 'Template created')),
            );
            _showTemplateModal(); // reopen select list
          }
        },
        onCancel: () {
          Navigator.of(context).pop();
          _showTemplateModal(); // back to select list
        },
      ),
    );
  }

  void _applyTemplate(ScheduleTemplate t) {
    _lastAppliedTemplateId = t.id;
    int applied = 0;
    int skipped = 0;
    for (final item in t.items) {
      final targetDate = _weekStart.add(Duration(days: item.dayOfWeek));
      final ds = _fmt(targetDate);
      final existing = _data[ds];
      if (existing != null &&
          !existing.isDeleted &&
          existing.existingId != null) {
        skipped++;
        continue;
      }
      final preserveId =
          existing?.isDeleted == true ? existing?.existingId : null;
      _data[ds] = _ReqDay(
        storeId: _workRoles
                .where((w) => w.id == item.workRoleId)
                .firstOrNull
                ?.storeId ??
            '',
        workRoleId: item.workRoleId,
        start: item.preferredStartTime,
        end: item.preferredEndTime,
        existingId: preserveId,
      );
      _viewMode[ds] = 'detail';
      applied++;
    }
    setState(() {});
    final msg = skipped > 0
        ? 'Applied $applied, skipped $skipped submitted'
        : '$applied day${applied != 1 ? 's' : ''} applied';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ────── Template Save Prompt ──────

  void _showTemplateSavePrompt() {
    final templates = ref.read(scheduleProvider).templates;
    String message;
    if (_lastAppliedTemplateId != null) {
      final tmpl = templates.where((t) => t.id == _lastAppliedTemplateId).firstOrNull;
      if (tmpl != null && _checkTemplateDiff(tmpl)) {
        message = 'This differs from "${tmpl.name}". Save as a new template?';
      } else {
        return; // No diff, no prompt
      }
    } else {
      message = 'Save this schedule as a template for future use?';
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Save Template?'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _saveSubmittedAsTemplate();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  bool _checkTemplateDiff(ScheduleTemplate tmpl) {
    // Compare template items vs current week's submitted data
    final templateDays = <int>{};
    for (final item in tmpl.items) {
      templateDays.add(item.dayOfWeek);
    }
    final currentDays = <int>{};
    for (int i = 0; i < 7; i++) {
      final ds = _fmt(_weekStart.add(Duration(days: i)));
      final d = _data[ds];
      if (d != null && !d.isEmpty && !d.isDeleted) {
        currentDays.add(i);
      }
    }
    if (templateDays.length != currentDays.length) return true;
    return !templateDays.every((d) => currentDays.contains(d)) ||
        !currentDays.every((d) => templateDays.contains(d));
  }

  void _saveSubmittedAsTemplate() {
    // Build template from current week's data
    final items = <Map<String, dynamic>>[];
    for (int i = 0; i < 7; i++) {
      final ds = _fmt(_weekStart.add(Duration(days: i)));
      final d = _data[ds];
      if (d == null || d.isEmpty || d.isDeleted) continue;
      final wr = _workRoles.where((w) => w.id == d.workRoleId).firstOrNull;
      final store = _stores.where((s) => s['id'] == d.storeId).firstOrNull;
      items.add({
        'day_of_week': i,
        'work_role_id': d.workRoleId,
        'work_role_name': wr?.displayName ?? '',
        'store_name': store?['name'] ?? '',
        'preferred_start_time': d.start,
        'preferred_end_time': d.end,
      });
    }
    // Pre-fill edit modal with this data
    final prefilled = ScheduleTemplate(
      id: '',
      name: '',
      isDefault: false,
      items: items
          .map((e) => ScheduleTemplateItem.fromJson(e))
          .toList(),
    );
    _showTemplateEditModal(null, prefilled: prefilled);
  }

  // ────── Submit ──────

  void _showSubmitConfirmation() {
    if (_hasOpenForms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Save or cancel open forms before submitting'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    if (!_hasChanges) return;

    final added = <String>[];
    final updated = <String>[];
    final deleted = <String>[];

    for (final ds in _data.keys.toList()..sort()) {
      final s = _status(ds);
      final d = _data[ds]!;
      final date = DateTime.parse(ds);
      final dayLabel = '${date.month}/${date.day} (${_weekdayLabels[date.weekday % 7]})';

      if (s == 'added') {
        final store = _stores.firstWhere(
            (st) => st['id'] == d.storeId, orElse: () => {'name': ''});
        final wr = _workRoles.where((w) => w.id == d.workRoleId).firstOrNull;
        added.add('$dayLabel ${store['name']} ${wr?.displayName ?? ''} ${_trimT(d.start)}-${_trimT(d.end)}');
      } else if (s == 'updated') {
        final store = _stores.firstWhere(
            (st) => st['id'] == d.storeId, orElse: () => {'name': ''});
        final wr = _workRoles.where((w) => w.id == d.workRoleId).firstOrNull;
        updated.add('$dayLabel ${store['name']} ${wr?.displayName ?? ''} ${_trimT(d.start)}-${_trimT(d.end)}');
      } else if (s == 'deleted') {
        final orig = _originals[ds];
        final wr = orig != null
            ? _workRoles.where((w) => w.id == orig.workRoleId).firstOrNull
            : null;
        deleted.add('$dayLabel ${wr?.displayName ?? ''}');
      }
    }

    final total = added.length + updated.length + deleted.length;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Submit $total Change${total != 1 ? 's' : ''}?'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (added.isNotEmpty) ...[
                Text('New: ${added.length}',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                ...added.map((a) => Text(a, style: const TextStyle(fontSize: 13))),
                const SizedBox(height: 8),
              ],
              if (updated.isNotEmpty) ...[
                Text('Updated: ${updated.length}',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                ...updated.map((u) => Text(u, style: const TextStyle(fontSize: 13))),
                const SizedBox(height: 8),
              ],
              if (deleted.isNotEmpty) ...[
                Text('Deleted: ${deleted.length}',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                ...deleted.map((d) => Text(d, style: const TextStyle(fontSize: 13))),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _submit();
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (!_hasChanges) return;
    setState(() => _isSubmitting = true);

    try {
      // Submit ALL changes across all weeks
      for (final ds in _data.keys.toList()) {
        final d = _data[ds]!;
        final status = _status(ds);
        final date = DateTime.parse(ds);

        if (status == 'added' && d.isComplete) {
          final created = await _service.submitRequest(
            storeId: d.storeId,
            workDate: date,
            workRoleId: d.workRoleId,
            preferredStartTime: d.start,
            preferredEndTime: d.end,
            note: d.note.isNotEmpty ? d.note : null,
          );
          d.existingId = created.id;
        } else if (status == 'updated' && d.existingId != null) {
          await _service.updateRequest(
            d.existingId!,
            storeId: d.storeId,
            workRoleId: d.workRoleId,
            preferredStartTime: d.start,
            preferredEndTime: d.end,
          );
        } else if (status == 'deleted' && d.existingId != null) {
          await _service.deleteRequest(d.existingId!);
        }
      }

      if (mounted) {
        // Reset submitted items: mark as "submitted" (set existingId, clear changes)
        for (final ds in _data.keys.toList()) {
          final s = _status(ds);
          if (s == 'added') {
            _originals[ds] = _data[ds]!.copy();
          } else if (s == 'updated') {
            _originals[ds] = _data[ds]!.copy();
          } else if (s == 'deleted') {
            _data.remove(ds);
            _originals.remove(ds);
          }
        }
        // Reload current week to get server IDs
        _loadedWeeks.remove(_fmt(_weekStart));
        await _ensureWeekLoaded(_weekStart);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Request submitted successfully'),
            backgroundColor: AppColors.success,
          ),
        );
        // Show template save prompt
        _showTemplateSavePrompt();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
}

// ────── Template Select Sheet ──────

class _TemplateSelectSheet extends StatefulWidget {
  final List<ScheduleTemplate> templates;
  final List<String> weekdayLabels;
  final void Function(ScheduleTemplate) onApply;
  final void Function(ScheduleTemplate) onEdit;
  final VoidCallback onCreate;
  final void Function(ScheduleTemplate) onDelete;

  const _TemplateSelectSheet({
    required this.templates,
    required this.weekdayLabels,
    required this.onApply,
    required this.onEdit,
    required this.onCreate,
    required this.onDelete,
  });

  @override
  State<_TemplateSelectSheet> createState() => _TemplateSelectSheetState();
}

class _TemplateSelectSheetState extends State<_TemplateSelectSheet> {
  String? _selectedId;
  final Set<String> _expanded = {};

  @override
  void initState() {
    super.initState();
    // Auto-select: default 템플릿 or 1개뿐이면 자동 선택
    if (widget.templates.length == 1) {
      _selectedId = widget.templates.first.id;
    } else {
      final def = widget.templates.where((t) => t.isDefault).firstOrNull;
      if (def != null) _selectedId = def.id;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 36, height: 4,
            margin: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(
                color: AppColors.border, borderRadius: BorderRadius.circular(2)),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
            child: Row(
              children: [
                const Text('My Templates',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.close, size: 22, color: AppColors.textMuted),
                  ),
                ),
              ],
            ),
          ),
          // List
          Flexible(
            child: widget.templates.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(32),
                    child: Text('No templates yet.\nCreate one to get started.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14, color: AppColors.textMuted)),
                  )
                : ListView(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    children: [
                      // Default first
                      ..._sorted().map(_buildCard),
                    ],
                  ),
          ),
          // Create button
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
            child: GestureDetector(
              onTap: widget.onCreate,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.border, width: 1.5, style: BorderStyle.solid),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add, size: 16, color: AppColors.textSecondary),
                    SizedBox(width: 6),
                    Text('Create New Template',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ),
          ),
          // Apply button
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _selectedId != null
                    ? () {
                        final t = widget.templates.firstWhere((t) => t.id == _selectedId);
                        widget.onApply(t);
                      }
                    : null,
                child: const Text('Apply Selected'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<ScheduleTemplate> _sorted() {
    final list = [...widget.templates];
    list.sort((a, b) => (b.isDefault ? 1 : 0) - (a.isDefault ? 1 : 0));
    return list;
  }

  Widget _buildCard(ScheduleTemplate t) {
    final isSelected = t.id == _selectedId;
    final isExpanded = _expanded.contains(t.id);

    return GestureDetector(
      onTap: () => setState(() => _selectedId = t.id),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? AppColors.accent : AppColors.border,
            width: isSelected ? 2 : 1.5,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row: radio + name + default badge + actions
            Row(
              children: [
                // Radio
                Container(
                  width: 20, height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? AppColors.accent : AppColors.textMuted,
                      width: 2,
                    ),
                  ),
                  child: isSelected
                      ? Center(
                          child: Container(
                            width: 10, height: 10,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.accent,
                            ),
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 10),
                // Name + sub
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t.name,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                      Text('${t.items.length} day${t.items.length != 1 ? 's' : ''} configured',
                          style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                    ],
                  ),
                ),
                if (t.isDefault)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                        color: AppColors.accentBg, borderRadius: BorderRadius.circular(999)),
                    child: const Text('Default',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.accent)),
                  ),
                // Edit
                GestureDetector(
                  onTap: () => widget.onEdit(t),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.edit_outlined, size: 16, color: AppColors.textSecondary),
                  ),
                ),
                // Delete
                GestureDetector(
                  onTap: () => widget.onDelete(t),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.delete_outline, size: 16, color: AppColors.danger),
                  ),
                ),
              ],
            ),
            // Expand toggle
            GestureDetector(
              onTap: () => setState(() {
                isExpanded ? _expanded.remove(t.id) : _expanded.add(t.id);
              }),
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Details', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                    Icon(isExpanded ? Icons.expand_less : Icons.expand_more,
                        size: 16, color: AppColors.textMuted),
                  ],
                ),
              ),
            ),
            // Detail rows
            if (isExpanded)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Column(
                  children: t.items.map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 36,
                          child: Text(widget.weekdayLabels[item.dayOfWeek],
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                        ),
                        Expanded(
                          child: Text(
                            '${item.storeName ?? ''} · ${item.workRoleName ?? ''} · ${_trimT(item.preferredStartTime)}-${_trimT(item.preferredEndTime)}',
                            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  )).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ────── Template Edit Sheet ──────

class _TemplateEditSheet extends StatefulWidget {
  final ScheduleTemplate? existing;
  final ScheduleTemplate? prefilled;
  final List<Map<String, dynamic>> stores;
  final List<WorkRole> workRoles;
  final List<String> weekdayLabels;
  final Future<void> Function(String name, bool isDefault, List<Map<String, dynamic>> items) onSave;
  final VoidCallback? onCancel;

  const _TemplateEditSheet({
    required this.existing,
    this.prefilled,
    required this.stores,
    required this.workRoles,
    required this.weekdayLabels,
    required this.onSave,
    this.onCancel,
  });

  @override
  State<_TemplateEditSheet> createState() => _TemplateEditSheetState();
}

class _TemplateEditSheetState extends State<_TemplateEditSheet> {
  late TextEditingController _nameCtrl;
  late bool _isDefault;
  // Per-day data: dayOfWeek -> {enabled, storeId, workRoleId, start, end}
  late List<_TmplDayData> _days;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final source = widget.existing ?? widget.prefilled;
    _nameCtrl = TextEditingController(text: widget.existing?.name ?? '');
    _isDefault = widget.existing?.isDefault ?? false;
    _days = List.generate(7, (i) {
      final item = source?.items
          .where((it) => it.dayOfWeek == i)
          .firstOrNull;
      if (item != null) {
        // Find storeId from workRole
        final wr = widget.workRoles.where((w) => w.id == item.workRoleId).firstOrNull;
        return _TmplDayData(
          enabled: true,
          storeId: wr?.storeId ?? '',
          workRoleId: item.workRoleId,
          start: item.preferredStartTime,
          end: item.preferredEndTime,
        );
      }
      return _TmplDayData();
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.existing == null;
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 36, height: 4,
            margin: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(
                color: AppColors.border, borderRadius: BorderRadius.circular(2)),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
            child: Row(
              children: [
                Text(isNew ? 'New Template' : 'Edit Template',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const Spacer(),
                GestureDetector(
                  onTap: widget.onCancel ?? () => Navigator.of(context).pop(),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.close, size: 22, color: AppColors.textMuted),
                  ),
                ),
              ],
            ),
          ),
          // Form
          Flexible(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                // Name
                const Text('Template Name',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                const SizedBox(height: 6),
                TextField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                    hintText: 'e.g., Regular Schedule',
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
                const SizedBox(height: 12),
                // Default checkbox
                GestureDetector(
                  onTap: () => setState(() => _isDefault = !_isDefault),
                  child: Row(
                    children: [
                      Icon(
                        _isDefault ? Icons.check_box : Icons.check_box_outline_blank,
                        size: 20,
                        color: _isDefault ? AppColors.accent : AppColors.textMuted,
                      ),
                      const SizedBox(width: 8),
                      const Text('Set as default',
                          style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Day rows
                ...List.generate(7, (i) => _buildDayRow(i)),
                const SizedBox(height: 16),
              ],
            ),
          ),
          // Footer
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: widget.onCancel ?? () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _saving ? null : _handleSave,
                    child: _saving
                        ? const SizedBox(width: 20, height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.white))
                        : const Text('Save'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayRow(int dayIdx) {
    final day = _days[dayIdx];
    final filteredRoles = day.storeId.isNotEmpty
        ? widget.workRoles.where((w) => w.storeId == day.storeId).toList()
        : <WorkRole>[];

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        border: Border.all(color: day.enabled ? AppColors.accent.withValues(alpha: 0.3) : AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // Day header with toggle
          GestureDetector(
            onTap: () => setState(() => day.enabled = !day.enabled),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  Icon(
                    day.enabled ? Icons.check_circle : Icons.circle_outlined,
                    size: 20,
                    color: day.enabled ? AppColors.accent : AppColors.textMuted,
                  ),
                  const SizedBox(width: 8),
                  Text(widget.weekdayLabels[dayIdx],
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: day.enabled ? AppColors.text : AppColors.textMuted,
                      )),
                  if (day.enabled && day.workRoleId.isNotEmpty) ...[
                    const Spacer(),
                    Text(
                      '${_trimT(day.start)}-${_trimT(day.end)}',
                      style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                    ),
                  ],
                ],
              ),
            ),
          ),
          // Fields (when enabled)
          if (day.enabled)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: Column(
                children: [
                  // Store dropdown
                  _tmplDropdown<String>(
                    value: day.storeId.isNotEmpty ? day.storeId : null,
                    hint: 'Store',
                    items: widget.stores
                        .map((s) => DropdownMenuItem(
                            value: s['id'] as String,
                            child: Text(s['name'] as String, style: const TextStyle(fontSize: 13))))
                        .toList(),
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() {
                        day.storeId = v;
                        day.workRoleId = '';
                        final roles = widget.workRoles.where((w) => w.storeId == v).toList();
                        if (roles.length == 1) {
                          day.workRoleId = roles.first.id;
                          if (day.start.isEmpty) day.start = roles.first.defaultStartTime ?? '';
                          if (day.end.isEmpty) day.end = roles.first.defaultEndTime ?? '';
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  // Work role dropdown
                  _tmplDropdown<String>(
                    value: day.workRoleId.isNotEmpty && filteredRoles.any((w) => w.id == day.workRoleId)
                        ? day.workRoleId
                        : null,
                    hint: day.storeId.isEmpty ? 'Select store first' : 'Work Role',
                    items: filteredRoles
                        .map((w) => DropdownMenuItem(
                            value: w.id, child: Text(w.displayName, style: const TextStyle(fontSize: 13))))
                        .toList(),
                    onChanged: filteredRoles.isEmpty ? null : (v) {
                      if (v == null) return;
                      setState(() {
                        day.workRoleId = v;
                        final wr = widget.workRoles.firstWhere((w) => w.id == v);
                        if (day.start.isEmpty) day.start = wr.defaultStartTime ?? '';
                        if (day.end.isEmpty) day.end = wr.defaultEndTime ?? '';
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  // Time row
                  Row(
                    children: [
                      Expanded(child: _tmplTimeField('Start', day.start, (v) => setState(() => day.start = v))),
                      const SizedBox(width: 8),
                      Expanded(child: _tmplTimeField('End', day.end, (v) => setState(() => day.end = v))),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _tmplDropdown<T>({
    required T? value,
    required String hint,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?>? onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border, width: 1.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: DropdownButton<T>(
        value: value,
        hint: Text(hint, style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
        isExpanded: true,
        underline: const SizedBox.shrink(),
        isDense: true,
        items: items,
        onChanged: onChanged,
      ),
    );
  }

  Widget _tmplTimeField(String label, String value, ValueChanged<String> onChanged) {
    return GestureDetector(
      onTap: () async {
        final parts = value.isNotEmpty ? value.split(':') : ['9', '0'];
        final initial = TimeOfDay(
          hour: int.tryParse(parts[0]) ?? 9,
          minute: int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0,
        );
        final picked = await showTimePicker(context: context, initialTime: initial);
        if (picked != null) {
          onChanged('${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}');
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border, width: 1.5),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                value.isNotEmpty ? _trimT(value) : label,
                style: TextStyle(
                  fontSize: 13,
                  color: value.isNotEmpty ? AppColors.text : AppColors.textMuted,
                ),
              ),
            ),
            const Icon(Icons.access_time, size: 14, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }

  void _handleSave() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a template name'), backgroundColor: AppColors.danger),
      );
      return;
    }
    // Build items from enabled days
    final items = <Map<String, dynamic>>[];
    for (int i = 0; i < 7; i++) {
      final d = _days[i];
      if (!d.enabled || d.workRoleId.isEmpty || d.start.isEmpty || d.end.isEmpty) continue;
      final wr = widget.workRoles.where((w) => w.id == d.workRoleId).firstOrNull;
      final store = widget.stores.where((s) => s['id'] == d.storeId).firstOrNull;
      items.add({
        'day_of_week': i,
        'work_role_id': d.workRoleId,
        'work_role_name': wr?.displayName ?? '',
        'store_name': store?['name'] ?? '',
        'preferred_start_time': d.start,
        'preferred_end_time': d.end,
      });
    }
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one day'), backgroundColor: AppColors.danger),
      );
      return;
    }
    setState(() => _saving = true);
    await widget.onSave(name, _isDefault, items);
  }
}

class _TmplDayData {
  bool enabled;
  String storeId;
  String workRoleId;
  String start;
  String end;

  _TmplDayData({
    this.enabled = false,
    this.storeId = '',
    this.workRoleId = '',
    this.start = '',
    this.end = '',
  });
}

// ────── Helpers ──────

String _fmt(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String _trimT(String t) {
  if (t.isEmpty) return '';
  final parts = t.split(':');
  if (parts.length < 2) return t;
  final h = int.tryParse(parts[0]) ?? 0;
  return '$h:${parts[1]}';
}
