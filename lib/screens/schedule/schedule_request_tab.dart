// Schedule request screen — 폼 기반 스케줄 신청 UI
//
// 주간 날짜별 카드 형태로 시프트 폼을 추가/수정/삭제하고
// 배치 제출한다. 템플릿 관리 바텀시트 포함.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/theme.dart';
import '../../models/schedule.dart';
import '../../providers/schedule_provider.dart';
import '../../services/schedule_service.dart';

// ─── Constants ───────────────────────────────────────

const _kWeekdays = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
const _kSnapMinutes = 15;

// ─── Shift Form Model ────────────────────────────────

class _ShiftForm {
  String localId;
  String? serverId;
  String? workRoleId;
  TimeOfDay? startTime;
  TimeOfDay? endTime;
  String status; // new, submitted, accepted, modified, rejected
  bool pendingDelete;
  bool locallyModified;

  _ShiftForm({
    required this.localId,
    this.serverId,
    this.workRoleId,
    this.startTime,
    this.endTime,
    this.status = 'new',
    this.pendingDelete = false,
    this.locallyModified = false,
  });

  bool get isEditable =>
      !pendingDelete && (status == 'new' || status == 'submitted');

  bool get isReadOnly =>
      status == 'accepted' || status == 'modified' || status == 'rejected';

  bool get hasOverlap => _overlapFlag;
  bool _overlapFlag = false;
}

// ─── Time Utilities ──────────────────────────────────

TimeOfDay _snapTo15(TimeOfDay t) {
  final snapped = ((t.minute + 7) ~/ _kSnapMinutes) * _kSnapMinutes;
  if (snapped >= 60) {
    return TimeOfDay(hour: (t.hour + 1) % 24, minute: 0);
  }
  return TimeOfDay(hour: t.hour, minute: snapped);
}

String _fmtTime(TimeOfDay t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

TimeOfDay? _parseTime(String? s) {
  if (s == null || s.isEmpty) return null;
  final p = s.split(':');
  if (p.length < 2) return null;
  return TimeOfDay(hour: int.parse(p[0]), minute: int.parse(p[1]));
}

String _fmtDate(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

int _timeToMinutes(TimeOfDay t) => t.hour * 60 + t.minute;

bool _timesOverlap(TimeOfDay s1, TimeOfDay e1, TimeOfDay s2, TimeOfDay e2) {
  var a1 = _timeToMinutes(s1), b1 = _timeToMinutes(e1);
  var a2 = _timeToMinutes(s2), b2 = _timeToMinutes(e2);
  // 자정 넘는 시프트: end <= start → end에 24h 추가
  if (b1 <= a1) b1 += 1440;
  if (b2 <= a2) b2 += 1440;
  return a1 < b2 && a2 < b1;
}

int _localIdCounter = 0;
String _nextLocalId() => 'local_${++_localIdCounter}';

// ─── Scroll-based Time Picker ────────────────────────

Future<TimeOfDay?> showScrollTimePicker(
  BuildContext context, {
  TimeOfDay? initial,
}) async {
  final init = initial ?? const TimeOfDay(hour: 9, minute: 0);
  // 15분 단위 목록 (0:00 ~ 23:45 = 96개)
  final options = <TimeOfDay>[
    for (int h = 0; h < 24; h++)
      for (int m = 0; m < 60; m += _kSnapMinutes) TimeOfDay(hour: h, minute: m),
  ];
  int initialIdx = 0;
  for (int i = 0; i < options.length; i++) {
    if (options[i].hour == init.hour && options[i].minute == init.minute) {
      initialIdx = i;
      break;
    }
  }

  final controller = FixedExtentScrollController(initialItem: initialIdx);
  TimeOfDay selected = options[initialIdx];

  final result = await showModalBottomSheet<TimeOfDay>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return _ScrollTimePicker(
        controller: controller,
        options: options,
        initial: selected,
      );
    },
  );
  controller.dispose();
  return result;
}

/// 스크롤 + 직접 입력 모드 지원 time picker
class _ScrollTimePicker extends StatefulWidget {
  final FixedExtentScrollController controller;
  final List<TimeOfDay> options;
  final TimeOfDay initial;

  const _ScrollTimePicker({
    required this.controller,
    required this.options,
    required this.initial,
  });

  @override
  State<_ScrollTimePicker> createState() => _ScrollTimePickerState();
}

class _ScrollTimePickerState extends State<_ScrollTimePicker> {
  late TimeOfDay _selected;
  bool _isInputMode = false;
  final _hourCtrl = TextEditingController();
  final _minCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selected = widget.initial;
  }

  @override
  void dispose() {
    _hourCtrl.dispose();
    _minCtrl.dispose();
    super.dispose();
  }

  TimeOfDay? _parseInput() {
    final h = int.tryParse(_hourCtrl.text);
    final m = int.tryParse(_minCtrl.text);
    if (h == null || m == null || h < 0 || h > 23 || m < 0 || m > 59) return null;
    return _snapTo15(TimeOfDay(hour: h, minute: m));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 300,
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(null),
                  child: const Text('Cancel',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 15)),
                ),
                // 모드 전환 버튼
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _isInputMode = !_isInputMode;
                      if (_isInputMode) {
                        _hourCtrl.text = _selected.hour.toString().padLeft(2, '0');
                        _minCtrl.text = _selected.minute.toString().padLeft(2, '0');
                      }
                    });
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _isInputMode ? Icons.access_time : Icons.keyboard,
                        size: 18,
                        color: AppColors.accent,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _isInputMode ? 'Scroll' : 'Type',
                        style: TextStyle(
                            color: AppColors.accent,
                            fontSize: 13,
                            fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () {
                    if (_isInputMode) {
                      final parsed = _parseInput();
                      Navigator.of(context).pop(parsed ?? _selected);
                    } else {
                      Navigator.of(context).pop(_selected);
                    }
                  },
                  child: Text('Done',
                      style: TextStyle(
                          color: AppColors.accent,
                          fontSize: 15,
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _isInputMode
                ? _buildInputMode()
                : ListWheelScrollView.useDelegate(
                    controller: widget.controller,
                    itemExtent: 44,
                    physics: const FixedExtentScrollPhysics(),
                    diameterRatio: 1.4,
                    onSelectedItemChanged: (idx) =>
                        _selected = widget.options[idx],
                    childDelegate: ListWheelChildBuilderDelegate(
                      childCount: widget.options.length,
                      builder: (ctx, idx) {
                        final t = widget.options[idx];
                        return Center(
                          child: Text(
                            _fmtTime(t),
                            style: const TextStyle(
                                fontSize: 20, fontWeight: FontWeight.w500),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputMode() {
    return Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 70,
            child: TextField(
              controller: _hourCtrl,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              maxLength: 2,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w600),
              decoration: const InputDecoration(
                counterText: '',
                hintText: 'HH',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Text(':', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w600)),
          ),
          SizedBox(
            width: 70,
            child: TextField(
              controller: _minCtrl,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              maxLength: 2,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w600),
              decoration: const InputDecoration(
                counterText: '',
                hintText: 'MM',
                border: OutlineInputBorder(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Main Widget ─────────────────────────────────────

class ScheduleRequestTab extends ConsumerStatefulWidget {
  final DateTime? targetDate;

  const ScheduleRequestTab({super.key, this.targetDate});

  @override
  ConsumerState<ScheduleRequestTab> createState() =>
      _ScheduleRequestTabState();
}

class _ScheduleRequestTabState extends ConsumerState<ScheduleRequestTab> {
  late DateTime _weekStart;
  String? _selectedStoreId;
  List<Map<String, dynamic>> _stores = [];
  List<WorkRole> _workRoles = [];
  bool _isLoading = false;
  bool _isSubmitting = false;
  int _loadGeneration = 0; // race condition 방지용

  // 날짜별 시프트 폼 목록: dayIndex(0=Sun) -> list of forms
  final Map<int, List<_ShiftForm>> _dayShifts = {};
  final List<String> _deletedServerIds = [];
  // 서버 원본 스냅샷: serverId -> (workRoleId, startTime, endTime)
  final Map<String, (String?, String?, String?)> _serverSnapshot = {};

  @override
  void initState() {
    super.initState();
    final target = widget.targetDate ?? DateTime.now();
    // 일요일 기준 주 시작
    _weekStart =
        DateTime(target.year, target.month, target.day - (target.weekday % 7));
    for (int i = 0; i < 7; i++) {
      _dayShifts[i] = [];
    }
    _loadStores();
  }

  // ── Data loading ───

  Future<void> _loadStores() async {
    setState(() => _isLoading = true);
    try {
      final svc = ref.read(scheduleServiceProvider);
      _stores = await svc.getMyStores();
    } catch (_) {}
    setState(() => _isLoading = false);
  }

  Future<void> _loadWorkRoles(String storeId) async {
    final gen = _loadGeneration;
    try {
      final svc = ref.read(scheduleServiceProvider);
      final roles = await svc.getWorkRoles(storeId: storeId);
      if (!mounted || gen != _loadGeneration) return; // stale response
      _workRoles = roles;
    } catch (_) {
      if (!mounted || gen != _loadGeneration) return;
      _workRoles = [];
    }
    setState(() {});
  }

  Future<void> _loadExistingRequests() async {
    if (_selectedStoreId == null) return;
    final gen = _loadGeneration;
    final storeId = _selectedStoreId;
    setState(() => _isLoading = true);
    try {
      final svc = ref.read(scheduleServiceProvider);
      final weekEnd = _weekStart.add(const Duration(days: 6));
      final requests = await svc.getMyRequests(
        dateFrom: _fmtDate(_weekStart),
        dateTo: _fmtDate(weekEnd),
      );
      if (!mounted || gen != _loadGeneration) return; // stale response
      // 기존 폼 + 스냅샷 클리어
      for (int i = 0; i < 7; i++) {
        _dayShifts[i] = [];
      }
      _deletedServerIds.clear();
      _serverSnapshot.clear();

      for (final req in requests) {
        if (req.storeId != storeId) continue;
        final dayIndex = req.workDate.weekday % 7; // 0=Sun
        _dayShifts[dayIndex]!.add(_ShiftForm(
          localId: _nextLocalId(),
          serverId: req.id,
          workRoleId: req.workRoleId,
          startTime: _parseTime(req.preferredStartTime),
          endTime: _parseTime(req.preferredEndTime),
          status: req.status,
        ));
        // 서버 원본 스냅샷 저장
        _serverSnapshot[req.id] = (
          req.workRoleId,
          req.preferredStartTime,
          req.preferredEndTime,
        );
      }
    } catch (_) {}
    if (!mounted || gen != _loadGeneration) return;
    _updateOverlaps();
    setState(() => _isLoading = false);
  }

  // ── Week navigation ───

  void _previousWeek() {
    _loadGeneration++;
    setState(() {
      _weekStart = DateTime(_weekStart.year, _weekStart.month, _weekStart.day - 7);
      for (int i = 0; i < 7; i++) _dayShifts[i] = [];
      _deletedServerIds.clear();
    });
    _loadExistingRequests();
  }

  void _nextWeek() {
    _loadGeneration++;
    setState(() {
      _weekStart = DateTime(_weekStart.year, _weekStart.month, _weekStart.day + 7);
      for (int i = 0; i < 7; i++) _dayShifts[i] = [];
      _deletedServerIds.clear();
    });
    _loadExistingRequests();
  }

  // ── Store selection ───

  void _onStoreChanged(String? storeId) {
    if (storeId == null || storeId == _selectedStoreId) return;
    _loadGeneration++; // 이전 비동기 응답 무시
    setState(() {
      _selectedStoreId = storeId;
      _workRoles = [];
      for (int i = 0; i < 7; i++) {
        _dayShifts[i] = [];
      }
      _deletedServerIds.clear();
    });
    _loadWorkRoles(storeId);
    _loadExistingRequests();
  }

  // ── Shift form operations ───

  void _addShift(int dayIndex) {
    setState(() {
      _dayShifts[dayIndex]!.add(_ShiftForm(localId: _nextLocalId()));
    });
  }

  void _removeShift(int dayIndex, int shiftIndex) {
    final form = _dayShifts[dayIndex]![shiftIndex];
    setState(() {
      if (form.serverId != null) {
        _deletedServerIds.add(form.serverId!);
      }
      _dayShifts[dayIndex]!.removeAt(shiftIndex);
      _updateOverlaps();
    });
  }

  void _updateOverlaps() {
    for (int day = 0; day < 7; day++) {
      final shifts = _dayShifts[day]!;
      for (final s in shifts) {
        s._overlapFlag = false;
      }
      for (int i = 0; i < shifts.length; i++) {
        for (int j = i + 1; j < shifts.length; j++) {
          final a = shifts[i], b = shifts[j];
          if (a.pendingDelete || b.pendingDelete) continue;
          if (a.startTime == null ||
              a.endTime == null ||
              b.startTime == null ||
              b.endTime == null) continue;
          if (_timesOverlap(a.startTime!, a.endTime!, b.startTime!, b.endTime!)) {
            a._overlapFlag = true;
            b._overlapFlag = true;
          }
        }
      }
    }
  }

  bool get _hasOverlaps {
    for (int d = 0; d < 7; d++) {
      for (final s in _dayShifts[d]!) {
        if (s.hasOverlap && !s.pendingDelete) return true;
      }
    }
    return false;
  }

  /// 실제 변경사항이 있는지 (서버 스냅샷 대비)
  bool get _hasChanges {
    // 현재 살아있는 서버 ID 수집
    final currentServerIds = <String>{};
    for (int d = 0; d < 7; d++) {
      for (final s in _dayShifts[d]!) {
        if (s.serverId != null) currentServerIds.add(s.serverId!);
      }
    }
    // 삭제된 건: 스냅샷에 있었는데 현재 없는 것
    for (final id in _serverSnapshot.keys) {
      if (!currentServerIds.contains(id)) return true;
    }
    // 신규 추가된 건
    for (int d = 0; d < 7; d++) {
      for (final s in _dayShifts[d]!) {
        if (s.serverId == null && s.startTime != null && s.endTime != null) {
          return true;
        }
        // 기존 건이 수정됨 — 스냅샷과 비교
        if (s.serverId != null && _serverSnapshot.containsKey(s.serverId)) {
          final (origRole, origStart, origEnd) = _serverSnapshot[s.serverId!]!;
          final curStart = s.startTime != null ? _fmtTime(s.startTime!) : null;
          final curEnd = s.endTime != null ? _fmtTime(s.endTime!) : null;
          if (s.workRoleId != origRole || curStart != origStart || curEnd != origEnd) {
            return true;
          }
        }
      }
    }
    return false;
  }

  bool get _canSubmit =>
      _selectedStoreId != null && _hasChanges && !_hasOverlaps;

  // ── Submit ───

  Future<void> _submit() async {
    if (!_canSubmit || _isSubmitting) return;
    setState(() => _isSubmitting = true);
    try {
      final svc = ref.read(scheduleServiceProvider);
      final creates = <Map<String, dynamic>>[];
      final updates = <Map<String, dynamic>>[];

      for (int day = 0; day < 7; day++) {
        final date = _weekStart.add(Duration(days: day));
        for (final form in _dayShifts[day]!) {
          if (form.pendingDelete) continue;
          if (form.startTime == null || form.endTime == null) continue;

          final data = <String, dynamic>{
            'store_id': _selectedStoreId!,
            'work_date': _fmtDate(date),
            'work_role_id': form.workRoleId,
            'preferred_start_time': _fmtTime(form.startTime!),
            'preferred_end_time': _fmtTime(form.endTime!),
          };

          if (form.serverId != null && form.locallyModified) {
            updates.add({'id': form.serverId!, ...data});
          } else if (form.serverId == null) {
            creates.add(data);
          }
        }
      }

      await svc.batchSubmit(
        creates: creates,
        updates: updates,
        deletes: _deletedServerIds,
      );

      // 제출 후 provider 새로고침 (await해서 팝 전에 완료)
      await ref.read(scheduleProvider.notifier).refresh();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Schedule request submitted')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit: $e')),
        );
      }
    }
    if (mounted) setState(() => _isSubmitting = false);
  }

  // ── Time picker ───

  Future<TimeOfDay?> _pickTime(TimeOfDay? initial) =>
      showScrollTimePicker(context, initial: initial);

  // ── Template application ───

  void _applyTemplate(ScheduleTemplate template) {
    setState(() {
      for (int day = 0; day < 7; day++) {
        // 기존 new 상태만 제거, 서버 데이터는 유지
        _dayShifts[day]!.removeWhere((s) => s.serverId == null);
      }
      for (final item in template.items) {
        final dayIndex = item.dayOfWeek; // 0=Sun
        if (dayIndex < 0 || dayIndex > 6) continue;
        _dayShifts[dayIndex]!.add(_ShiftForm(
          localId: _nextLocalId(),
          workRoleId: item.workRoleId,
          startTime: _parseTime(item.preferredStartTime),
          endTime: _parseTime(item.preferredEndTime),
        ));
      }
      _updateOverlaps();
    });
  }

  // ── Build ───

  @override
  Widget build(BuildContext context) {
    final weekEnd = _weekStart.add(const Duration(days: 6));
    final weekLabel =
        '${_weekStart.month}/${_weekStart.day} ~ ${weekEnd.month}/${weekEnd.day}';

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Schedule Request'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (v) {
              if (v == 'templates') _showTemplatesSheet();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                  value: 'templates', child: Text('My Templates')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Week navigation ──
          Container(
            color: AppColors.white,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: _previousWeek,
                ),
                Text(weekLabel,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600)),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: _nextWeek,
                ),
              ],
            ),
          ),
          // ── Toolbar: store + templates ──
          Container(
            color: AppColors.white,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              children: [
                Expanded(child: _buildStoreDropdown()),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _selectedStoreId != null
                      ? _showTemplatesSheet
                      : null,
                  icon: const Icon(Icons.bookmark_outline, size: 18),
                  label: const Text('Templates'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.accent,
                    side: const BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // ── Day cards ──
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _selectedStoreId == null
                    ? _buildNoStoreMessage()
                    : _buildDayCards(),
          ),
        ],
      ),
      // ── Submit bar ──
      bottomNavigationBar: _buildSubmitBar(),
    );
  }

  Widget _buildStoreDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: _selectedStoreId,
          hint: const Text('Select store',
              style: TextStyle(color: AppColors.textMuted, fontSize: 14)),
          items: _stores.map((s) {
            final id = s['id'] as String;
            final name = s['name'] as String? ?? 'Unknown';
            return DropdownMenuItem(value: id, child: Text(name, style: const TextStyle(fontSize: 14)));
          }).toList(),
          onChanged: _onStoreChanged,
        ),
      ),
    );
  }

  Widget _buildNoStoreMessage() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.store_outlined, size: 48, color: AppColors.textMuted),
          SizedBox(height: 12),
          Text('Select a store first',
              style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 15,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildDayCards() {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: 7,
      itemBuilder: (context, dayIndex) {
        final date = _weekStart.add(Duration(days: dayIndex));
        final dayLabel =
            '${date.month}/${date.day} ${_kWeekdays[dayIndex]}';
        final shifts = _dayShifts[dayIndex]!;
        final isToday = _isToday(date);

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: isToday ? AppColors.accent : AppColors.border,
              width: isToday ? 1.5 : 1,
            ),
          ),
          color: AppColors.white,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Day header
                Row(
                  children: [
                    if (isToday)
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(right: 6),
                        decoration: const BoxDecoration(
                          color: AppColors.accent,
                          shape: BoxShape.circle,
                        ),
                      ),
                    Text(dayLabel,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isToday
                              ? AppColors.accent
                              : AppColors.text,
                        )),
                  ],
                ),
                const SizedBox(height: 8),
                // Shift forms
                if (shifts.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('No shifts',
                        style: TextStyle(
                            color: AppColors.textMuted, fontSize: 13)),
                  ),
                ...shifts.asMap().entries.map((entry) =>
                    _buildShiftForm(dayIndex, entry.key, entry.value)),
                // Add shift button
                if (_selectedStoreId != null)
                  TextButton.icon(
                    onPressed: () => _addShift(dayIndex),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add shift'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.accent,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      textStyle: const TextStyle(fontSize: 13),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildShiftForm(int dayIndex, int shiftIndex, _ShiftForm form) {
    final hasOverlap = form.hasOverlap;
    final isReadOnly = form.isReadOnly;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isReadOnly ? AppColors.bg : AppColors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: hasOverlap
              ? AppColors.danger
              : isReadOnly
                  ? AppColors.border
                  : AppColors.border,
          width: hasOverlap ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: status + delete
          Row(
            children: [
              if (form.serverId != null)
                _buildStatusBadge(form.status),
              const Spacer(),
              if (!isReadOnly)
                InkWell(
                  onTap: () => _removeShift(dayIndex, shiftIndex),
                  child: const Icon(Icons.close, size: 18, color: AppColors.danger),
                ),
            ],
          ),
          if (form.serverId != null) const SizedBox(height: 6),
          // Role dropdown
          _buildRoleDropdown(dayIndex, shiftIndex, form, isReadOnly),
          const SizedBox(height: 8),
          // Time row
          Row(
            children: [
              Expanded(
                child: _buildTimePicker(
                  label: 'Start',
                  value: form.startTime,
                  enabled: !isReadOnly,
                  onPick: () async {
                    final t = await _pickTime(form.startTime);
                    if (t != null) {
                      setState(() {
                        form.startTime = t;
                        form.locallyModified = true;
                        _updateOverlaps();
                      });
                    }
                  },
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text('~',
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 16)),
              ),
              Expanded(
                child: _buildTimePicker(
                  label: 'End',
                  value: form.endTime,
                  enabled: !isReadOnly,
                  onPick: () async {
                    final t = await _pickTime(form.endTime);
                    if (t != null) {
                      setState(() {
                        form.endTime = t;
                        form.locallyModified = true;
                        _updateOverlaps();
                      });
                    }
                  },
                ),
              ),
            ],
          ),
          // Overlap warning
          if (hasOverlap)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text('Overlaps with another shift',
                  style: TextStyle(color: AppColors.danger, fontSize: 12)),
            ),
        ],
      ),
    );
  }

  Widget _buildRoleDropdown(
      int dayIndex, int shiftIndex, _ShiftForm form, bool isReadOnly) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
        color: isReadOnly ? AppColors.bg : AppColors.white,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: form.workRoleId,
          hint: const Text('Select role',
              style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
          items: _workRoles.map((r) {
            return DropdownMenuItem(
                value: r.id,
                child: Text(r.displayName,
                    style: const TextStyle(fontSize: 13),
                    overflow: TextOverflow.ellipsis));
          }).toList(),
          onChanged: isReadOnly
              ? null
              : (v) {
                  setState(() {
                    form.workRoleId = v;
                    form.locallyModified = true;
                    // 역할 선택 시 기본 시간 자동 채움
                    if (v != null) {
                      final role =
                          _workRoles.where((r) => r.id == v).firstOrNull;
                      if (role != null) {
                        if (form.startTime == null &&
                            role.defaultStartTime != null) {
                          form.startTime = _parseTime(role.defaultStartTime);
                        }
                        if (form.endTime == null &&
                            role.defaultEndTime != null) {
                          form.endTime = _parseTime(role.defaultEndTime);
                        }
                      }
                    }
                    _updateOverlaps();
                  });
                },
        ),
      ),
    );
  }

  Widget _buildTimePicker({
    required String label,
    required TimeOfDay? value,
    required bool enabled,
    required VoidCallback onPick,
  }) {
    return InkWell(
      onTap: enabled ? onPick : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(8),
          color: enabled ? AppColors.white : AppColors.bg,
        ),
        child: Row(
          children: [
            Icon(Icons.access_time,
                size: 16,
                color: enabled ? AppColors.textSecondary : AppColors.textMuted),
            const SizedBox(width: 6),
            Text(
              value != null ? _fmtTime(value) : label,
              style: TextStyle(
                fontSize: 13,
                color: value != null
                    ? AppColors.text
                    : AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    final (Color bg, Color fg, String label) = switch (status) {
      'submitted' => (AppColors.accentBg, AppColors.accent, 'Submitted'),
      'accepted' => (AppColors.successBg, AppColors.success, 'Approved'),
      'modified' => (AppColors.warningBg, AppColors.warning, 'Modified'),
      'rejected' => (AppColors.dangerBg, AppColors.danger, 'Rejected'),
      _ => (AppColors.bg, AppColors.textSecondary, status),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label,
          style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildSubmitBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _canSubmit && !_isSubmitting ? _submit : null,
          style: ElevatedButton.styleFrom(
            backgroundColor:
                _canSubmit ? AppColors.accent : AppColors.textMuted,
            foregroundColor: AppColors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
          child: _isSubmitting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.white))
              : const Text('Submit Request',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  // ─── Templates Bottom Sheet ────────────────────────

  void _showTemplatesSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _TemplatesSheet(
        storeId: _selectedStoreId,
        stores: _stores,
        workRoles: _workRoles,
        scheduleService: ref.read(scheduleServiceProvider),
        onApplyTemplate: (template) {
          Navigator.of(context).pop();
          _applyTemplate(template);
        },
        onTemplateChanged: () {
          // 템플릿 CRUD 후 provider 갱신
          ref.read(scheduleProvider.notifier).refreshTemplates();
        },
      ),
    );
  }
}

// ─── Templates Bottom Sheet Widget ───────────────────

class _TemplatesSheet extends StatefulWidget {
  final String? storeId;
  final List<Map<String, dynamic>> stores;
  final List<WorkRole> workRoles;
  final ScheduleService scheduleService;
  final void Function(ScheduleTemplate) onApplyTemplate;
  final VoidCallback onTemplateChanged;

  const _TemplatesSheet({
    required this.storeId,
    required this.stores,
    required this.workRoles,
    required this.scheduleService,
    required this.onApplyTemplate,
    required this.onTemplateChanged,
  });

  @override
  State<_TemplatesSheet> createState() => _TemplatesSheetState();
}

class _TemplatesSheetState extends State<_TemplatesSheet> {
  List<ScheduleTemplate> _templates = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTemplates();
  }

  Future<void> _loadTemplates() async {
    setState(() => _isLoading = true);
    try {
      _templates = await widget.scheduleService.getMyTemplates();
    } catch (_) {}
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.85,
      expand: false,
      builder: (context, scrollCtrl) {
        return Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Title
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Text('My Templates',
                      style:
                          TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      controller: scrollCtrl,
                      padding: const EdgeInsets.all(16),
                      children: [
                        ..._templates.map(_buildTemplateItem),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: () => _showCreateEditTemplate(null),
                          icon: const Icon(Icons.add),
                          label: const Text('Create New Template'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.accent,
                            side: const BorderSide(color: AppColors.accent),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTemplateItem(ScheduleTemplate template) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(template.name,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600)),
              ),
              if (template.isDefault)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.accentBg,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('Default',
                      style: TextStyle(
                          color: AppColors.accent,
                          fontSize: 10,
                          fontWeight: FontWeight.w600)),
                ),
            ],
          ),
          if (template.items.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              '${template.items.length} shifts',
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 12),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Builder(builder: (_) {
                final canUse = widget.storeId != null &&
                    template.storeId == widget.storeId;
                return Opacity(
                  opacity: canUse ? 1.0 : 0.4,
                  child: _templateAction('Use', Icons.play_arrow, () {
                    if (!canUse) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text(
                                'Select the matching store to use this template')),
                      );
                      return;
                    }
                    widget.onApplyTemplate(template);
                  }),
                );
              }),
              const SizedBox(width: 8),
              _templateAction('Edit', Icons.edit_outlined, () {
                _showCreateEditTemplate(template);
              }),
              const SizedBox(width: 8),
              _templateAction('Delete', Icons.delete_outline, () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Delete Template'),
                    content: Text(
                        'Delete "${template.name}"? This cannot be undone.'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancel')),
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Delete',
                              style: TextStyle(color: AppColors.danger))),
                    ],
                  ),
                );
                if (confirm == true) {
                  try {
                    await widget.scheduleService
                        .deleteTemplate(template.id);
                    widget.onTemplateChanged();
                    _loadTemplates();
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to delete: $e')),
                      );
                    }
                  }
                }
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _templateAction(String label, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.accent),
          const SizedBox(width: 4),
          Text(label,
              style: const TextStyle(
                  color: AppColors.accent,
                  fontSize: 12,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  // ── Create / Edit template sheet ───

  void _showCreateEditTemplate(ScheduleTemplate? existing) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _TemplateFormSheet(
        existing: existing,
        stores: widget.stores,
        currentStoreId: widget.storeId,
        scheduleService: widget.scheduleService,
        onSaved: () {
          widget.onTemplateChanged();
          _loadTemplates();
        },
      ),
    );
  }
}

// ─── Template Create/Edit Form ───────────────────────

class _TemplateFormSheet extends StatefulWidget {
  final ScheduleTemplate? existing;
  final List<Map<String, dynamic>> stores;
  final String? currentStoreId;
  final ScheduleService scheduleService;
  final VoidCallback onSaved;

  const _TemplateFormSheet({
    this.existing,
    required this.stores,
    this.currentStoreId,
    required this.scheduleService,
    required this.onSaved,
  });

  @override
  State<_TemplateFormSheet> createState() => _TemplateFormSheetState();
}

class _TemplateFormSheetState extends State<_TemplateFormSheet> {
  final _nameController = TextEditingController();
  bool _isDefault = false;
  String? _storeId;
  List<Map<String, dynamic>> _stores = [];
  List<WorkRole> _roles = [];
  bool _isSaving = false;
  bool _isLoadingStores = true;

  // 요일별 항목: dayOfWeek -> list of { workRoleId, start, end }
  final Map<int, List<_TemplateItemForm>> _items = {};

  @override
  void initState() {
    super.initState();
    for (int i = 0; i < 7; i++) {
      _items[i] = [];
    }
    if (widget.existing != null) {
      _nameController.text = widget.existing!.name;
      _isDefault = widget.existing!.isDefault;
      _storeId = widget.existing!.storeId ?? widget.currentStoreId;
      for (final item in widget.existing!.items) {
        final dayIndex = item.dayOfWeek;
        if (dayIndex < 0 || dayIndex > 6) continue;
        _items[dayIndex]!.add(_TemplateItemForm(
          workRoleId: item.workRoleId,
          startTime: _parseTime(item.preferredStartTime),
          endTime: _parseTime(item.preferredEndTime),
        ));
      }
    } else {
      _storeId = widget.currentStoreId;
    }
    _loadStores();
  }

  Future<void> _loadStores() async {
    try {
      _stores = await widget.scheduleService.getMyStores();
    } catch (_) {
      _stores = widget.stores; // fallback
    }
    _isLoadingStores = false;
    if (_storeId != null) await _loadRoles(_storeId!);
    if (mounted) setState(() {});
  }

  Future<void> _loadRoles(String storeId) async {
    try {
      _roles = await widget.scheduleService.getWorkRoles(storeId: storeId);
    } catch (_) {
      _roles = [];
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    setState(() => _isSaving = true);
    try {
      final items = <Map<String, dynamic>>[];
      for (int d = 0; d < 7; d++) {
        for (final item in _items[d]!) {
          if (item.startTime == null || item.endTime == null) continue;
          items.add({
            'day_of_week': d,
            'work_role_id': item.workRoleId,
            'preferred_start_time': _fmtTime(item.startTime!),
            'preferred_end_time': _fmtTime(item.endTime!),
          });
        }
      }

      if (widget.existing != null) {
        await widget.scheduleService.updateTemplate(
          widget.existing!.id,
          name: name,
          isDefault: _isDefault,
          items: items,
        );
      } else {
        await widget.scheduleService.createTemplate(
          name: name,
          isDefault: _isDefault,
          items: items,
          storeId: _storeId,
        );
      }
      widget.onSaved();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    }
    if (mounted) setState(() => _isSaving = false);
  }

  Future<TimeOfDay?> _pickTime(TimeOfDay? initial) =>
      showScrollTimePicker(context, initial: initial);

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollCtrl) {
        return Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Title
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Text(isEdit ? 'Edit Template' : 'New Template',
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                controller: scrollCtrl,
                padding: const EdgeInsets.all(16),
                children: [
                  // Name
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Template Name',
                      hintText: 'e.g. Weekday mornings',
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Store (locked on edit)
                  if (!isEdit) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.border),
                        borderRadius: BorderRadius.circular(12),
                        color: AppColors.white,
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: _storeId,
                          hint: const Text('Select store',
                              style: TextStyle(color: AppColors.textMuted)),
                          items: _stores.map((s) {
                            return DropdownMenuItem(
                              value: s['id'] as String,
                              child: Text(s['name'] as String? ?? 'Unknown'),
                            );
                          }).toList(),
                          onChanged: (v) {
                            if (v == null) return;
                            setState(() => _storeId = v);
                            _loadRoles(v);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ] else ...[
                    // Show store name (locked)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.bg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Text(
                        _stores
                                .where((s) => s['id'] == _storeId)
                                .map((s) => s['name'] as String?)
                                .firstOrNull ??
                            (_isLoadingStores ? 'Loading...' : 'Store'),
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  // Default toggle
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Set as default',
                        style: TextStyle(fontSize: 14)),
                    value: _isDefault,
                    onChanged: (v) => setState(() => _isDefault = v),
                  ),
                  const SizedBox(height: 8),
                  // Day items
                  for (int d = 0; d < 7; d++) ...[
                    Text(_kWeekdays[d],
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary)),
                    const SizedBox(height: 4),
                    ..._items[d]!.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final item = entry.value;
                      return _buildTemplateItemRow(d, idx, item);
                    }),
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _items[d]!.add(_TemplateItemForm());
                        });
                      },
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Add', style: TextStyle(fontSize: 12)),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.accent,
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 32),
                      ),
                    ),
                    if (d < 6) const Divider(),
                  ],
                ],
              ),
            ),
            // Save button
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.white))
                      : Text(isEdit ? 'Save Template' : 'Create'),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTemplateItemRow(int day, int idx, _TemplateItemForm item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          // Role
          Expanded(
            flex: 3,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(6),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  isDense: true,
                  value: item.workRoleId,
                  hint: const Text('Role',
                      style:
                          TextStyle(color: AppColors.textMuted, fontSize: 12)),
                  items: _roles.map((r) {
                    return DropdownMenuItem(
                      value: r.id,
                      child: Text(r.displayName,
                          style: const TextStyle(fontSize: 12),
                          overflow: TextOverflow.ellipsis),
                    );
                  }).toList(),
                  onChanged: (v) {
                    setState(() {
                      item.workRoleId = v;
                      // 역할 선택 시 기본 시간 자동 채움
                      if (v != null) {
                        final role = _roles.where((r) => r.id == v).firstOrNull;
                        if (role != null) {
                          if (item.startTime == null && role.defaultStartTime != null) {
                            item.startTime = _parseTime(role.defaultStartTime);
                          }
                          if (item.endTime == null && role.defaultEndTime != null) {
                            item.endTime = _parseTime(role.defaultEndTime);
                          }
                        }
                      }
                    });
                  },
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          // Start time
          Expanded(
            flex: 2,
            child: InkWell(
              onTap: () async {
                final t = await _pickTime(item.startTime);
                if (t != null) setState(() => item.startTime = t);
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  item.startTime != null
                      ? _fmtTime(item.startTime!)
                      : 'Start',
                  style: TextStyle(
                    fontSize: 12,
                    color: item.startTime != null
                        ? AppColors.text
                        : AppColors.textMuted,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 2),
            child: Text('~',
                style:
                    TextStyle(color: AppColors.textSecondary, fontSize: 12)),
          ),
          // End time
          Expanded(
            flex: 2,
            child: InkWell(
              onTap: () async {
                final t = await _pickTime(item.endTime);
                if (t != null) setState(() => item.endTime = t);
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  item.endTime != null ? _fmtTime(item.endTime!) : 'End',
                  style: TextStyle(
                    fontSize: 12,
                    color: item.endTime != null
                        ? AppColors.text
                        : AppColors.textMuted,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
          // Delete
          InkWell(
            onTap: () {
              setState(() => _items[day]!.removeAt(idx));
            },
            child: const Padding(
              padding: EdgeInsets.only(left: 4),
              child: Icon(Icons.close, size: 16, color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Template Item Form Model ────────────────────────

class _TemplateItemForm {
  String? workRoleId;
  TimeOfDay? startTime;
  TimeOfDay? endTime;

  _TemplateItemForm({this.workRoleId, this.startTime, this.endTime});
}
