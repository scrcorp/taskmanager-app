// Schedule request tab — 타임라인 바 기반 스케줄 신청 UI
//
// 날짜별 N건 타임블록, 36시간 범위 수평 스크롤 타임라인.
// 드래그 리사이즈, 바텀시트 편집, 배치 제출.
import 'dart:math';
import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/theme.dart';
import '../../models/schedule.dart';
import '../../providers/schedule_provider.dart';
import '../../services/schedule_service.dart';

// ─── Constants ───────────────────────────────────────

const _kTimelineHours = 36.0; // 0:00 ~ +12:00
const _kVisibleHours = 14.0; // 한 화면에 보이는 시간
const _kZoom = _kTimelineHours / _kVisibleHours; // 4x
const _kTrackHeight = 44.0;
const _kMinBlockHours = 0.25; // 15분
const _kSnapMinutes = 15;
const _kDefaultBlockHours = 6.0;
const _kDefaultStart = 9.0;
const _kScrollIndicatorHeight = 6.0;
const _weekdayLabels = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

// ─── Time Block Model ────────────────────────────────

class _TimeBlock {
  String id;
  String? serverId;
  String storeId;
  String storeName;
  String workRoleId;
  String workRoleName;
  double start; // 0.0 ~ 36.0
  double end;
  String status; // new, submitted, approved, modified, rejected
  String? note;
  double? origStart;
  double? origEnd;
  String? origWorkRoleId;
  String? rejectionReason;
  bool pendingDelete; // 삭제 대기 (submit 시 서버에서 삭제)
  bool locallyModified; // 로컬에서 수정됨 (아직 서버 미반영)

  _TimeBlock({
    required this.id,
    this.serverId,
    required this.storeId,
    required this.storeName,
    required this.workRoleId,
    required this.workRoleName,
    required this.start,
    required this.end,
    required this.status,
    this.note,
    this.origStart,
    this.origEnd,
    this.origWorkRoleId,
    this.rejectionReason,
    this.pendingDelete = false,
    this.locallyModified = false,
  });

  bool get isEditable => !pendingDelete && (status == 'new' || status == 'submitted');
  bool get isIncomplete => workRoleId.isEmpty && isEditable;
  /// 서버에 반영된 상태인지 (실선 표시 대상)
  bool get isSynced => serverId != null && !locallyModified && !pendingDelete && status != 'new';
  double get hours => end - start;

  _TimeBlock copy() => _TimeBlock(
        id: id,
        serverId: serverId,
        storeId: storeId,
        storeName: storeName,
        workRoleId: workRoleId,
        workRoleName: workRoleName,
        start: start,
        end: end,
        status: status,
        note: note,
        origStart: origStart,
        origEnd: origEnd,
        origWorkRoleId: origWorkRoleId,
        rejectionReason: rejectionReason,
        pendingDelete: pendingDelete,
        locallyModified: locallyModified,
      );
}

// ─── Time Utilities ──────────────────────────────────

double _parseHHMM(String t) {
  final p = t.split(':');
  return int.parse(p[0]) + int.parse(p[1]) / 60;
}

(double, double) _parseServerTimes(String startStr, String endStr) {
  final s = _parseHHMM(startStr);
  var e = _parseHHMM(endStr);
  if (e <= s) e += 24;
  return (s, e);
}

String _toServerTime(double h) {
  final a = h >= 24 ? h - 24 : h;
  return '${a.floor().toString().padLeft(2, '0')}:${((a % 1) * 60).round().toString().padLeft(2, '0')}';
}

String _fmtHour(double h) {
  var totalMin = (h * 60).round();
  final hr = (totalMin ~/ 60) % 24;
  final mn = totalMin % 60;
  return '${hr.toString().padLeft(2, '0')}:${mn.toString().padLeft(2, '0')}';
}

String _fmtDuration(double hours) {
  final h = hours.floor();
  final m = ((hours - h) * 60).round();
  if (m == 0) return '${h}h';
  return '${h}h ${m}m';
}

double _snap(double h) => (h * 60 / _kSnapMinutes).round() * _kSnapMinutes / 60;

/// 5분 단위 스냅
double _snap5(double h) => (h * 60 / 5).round() * 5 / 60;

String _fmt(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String _mapStatus(String serverStatus) {
  switch (serverStatus) {
    case 'accepted':
      return 'approved';
    case 'modified':
      return 'modified';
    default:
      return serverStatus;
  }
}

int _nextLocalId = 0;
String _genLocalId() => '__local_${_nextLocalId++}';

// ─── Status Colors ───────────────────────────────────

Color _blockColor(String status) {
  switch (status) {
    case 'approved':
      return AppColors.success;
    case 'submitted':
      return AppColors.accent;
    case 'new':
      return AppColors.accent;
    case 'modified':
      return AppColors.warning;
    case 'rejected':
      return AppColors.danger;
    default:
      return AppColors.accent;
  }
}

Color _blockBgColor(String status) {
  switch (status) {
    case 'approved':
      return AppColors.successBg;
    case 'submitted':
      return AppColors.accentBg;
    case 'new':
      return AppColors.accentBg;
    case 'modified':
      return AppColors.warningBg;
    case 'rejected':
      return AppColors.dangerBg;
    default:
      return AppColors.accentBg;
  }
}

String _statusLabel(String status) {
  switch (status) {
    case 'approved':
      return 'Approved';
    case 'submitted':
      return 'Submitted';
    case 'new':
      return 'New';
    case 'modified':
      return 'Modified';
    case 'rejected':
      return 'Rejected';
    default:
      return status;
  }
}

class _PendingBlock {
  final String ds;
  final int dayOfWeek;
  final String storeId;
  final String storeName;
  final String workRoleId;
  final String workRoleName;
  final double start;
  final double end;

  const _PendingBlock({
    required this.ds, required this.dayOfWeek,
    required this.storeId, required this.storeName,
    required this.workRoleId, required this.workRoleName,
    required this.start, required this.end,
  });
}

// ═══════════════════════════════════════════════════════
// Main Widget
// ═══════════════════════════════════════════════════════

class ScheduleRequestTab extends ConsumerStatefulWidget {
  final DateTime? targetDate;
  const ScheduleRequestTab({super.key, this.targetDate});

  @override
  ConsumerState<ScheduleRequestTab> createState() => _ScheduleRequestTabState();
}

class _ScheduleRequestTabState extends ConsumerState<ScheduleRequestTab> {
  late DateTime _weekStart;
  final Map<String, List<_TimeBlock>> _data = {};
  final Map<String, List<_TimeBlock>> _originals = {};
  final Set<String> _loadedWeeks = {};
  bool _isSubmitting = false;
  String? _selectedBlockId;
  bool _scrollToSelected = false;

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
  List<Map<String, dynamic>> get _stores => ref.read(scheduleProvider).stores;
  List<WorkRole> get _workRoles => ref.read(scheduleProvider).workRoles;

  // ─── Data Loading ────────────────────────────────

  Future<void> _ensureWeekLoaded(DateTime weekStart) async {
    final key = _fmt(weekStart);
    if (_loadedWeeks.contains(key)) {
      if (mounted) setState(() {});
      return;
    }

    final dateFrom = _fmt(weekStart);
    final dateTo = _fmt(weekStart.add(const Duration(days: 6)));

    try {
      // 1) Entries 먼저 로드 — 확정된 스케줄 우선
      // entry에 request_id가 있으면 해당 request는 이미 확정된 것이므로 제외
      final coveredRequestIds = <String>{};
      final entries =
          await _service.getMyEntries(dateFrom: dateFrom, dateTo: dateTo);
      for (final e in entries) {
        if (e.requestId != null) coveredRequestIds.add(e.requestId!);

        final ds = _fmt(e.workDate);
        _data.putIfAbsent(ds, () => []);

        double start = _kDefaultStart, end = _kDefaultStart + _kDefaultBlockHours;
        if (e.startTime.isNotEmpty && e.endTime.isNotEmpty) {
          final (s, en) = _parseServerTimes(e.startTime, e.endTime);
          start = s;
          end = en;
        }

        _data[ds]!.add(_TimeBlock(
          id: e.id,
          serverId: e.id,
          storeId: e.storeId,
          storeName: e.storeName ?? '',
          workRoleId: e.workRoleId ?? '',
          workRoleName: e.workRoleName ?? '',
          start: start,
          end: end,
          status: 'approved',
        ));
      }

      // 2) Requests — entry로 이미 확정된 request는 제외
      final requests =
          await _service.getMyRequests(dateFrom: dateFrom, dateTo: dateTo);
      for (final r in requests) {
        // 이미 entry로 확정된 request는 중복이므로 표시하지 않음
        if (coveredRequestIds.contains(r.id)) continue;

        final ds = _fmt(r.workDate);
        _data.putIfAbsent(ds, () => []);

        double start = _kDefaultStart, end = _kDefaultStart + _kDefaultBlockHours;
        if (r.preferredStartTime != null && r.preferredEndTime != null) {
          final (s, e) = _parseServerTimes(r.preferredStartTime!, r.preferredEndTime!);
          start = s;
          end = e;
        }

        double? origS, origE;
        if (r.originalStartTime != null) origS = _parseHHMM(r.originalStartTime!);
        if (r.originalEndTime != null) {
          origE = _parseHHMM(r.originalEndTime!);
          if (origS != null && origE <= origS) origE += 24;
        }

        final block = _TimeBlock(
          id: r.id,
          serverId: r.id,
          storeId: r.storeId,
          storeName: r.storeName ?? '',
          workRoleId: r.workRoleId ?? '',
          workRoleName: r.workRoleName ?? '',
          start: start,
          end: end,
          status: _mapStatus(r.status),
          note: r.note,
          origStart: origS,
          origEnd: origE,
          rejectionReason: r.rejectedReason,
        );
        _data[ds]!.add(block);
      }

      // Save originals
      for (final ds in _data.keys) {
        _originals.putIfAbsent(ds, () => []);
        for (final b in _data[ds]!) {
          if (b.serverId != null &&
              !_originals[ds]!.any((o) => o.id == b.id)) {
            _originals[ds]!.add(b.copy());
          }
        }
      }

      _loadedWeeks.add(key);
    } catch (_) {}
    if (mounted) setState(() {});
  }

  // ─── Change Detection ────────────────────────────

  bool get _hasChanges {
    for (final ds in _data.keys) {
      final blocks = _data[ds]!;
      for (final b in blocks) {
        if (b.status == 'new' && !b.isIncomplete) return true;
        if (b.pendingDelete) return true;
        if (b.locallyModified) return true;
      }
    }
    return false;
  }

  Map<String, int> get _statusCounts {
    int approved = 0, submitted = 0, newCount = 0, modified = 0, rejected = 0;
    for (final ds in _data.keys) {
      // 현재 주만 카운트
      final date = DateTime.tryParse(ds);
      if (date == null) continue;
      if (date.isBefore(_weekStart) ||
          date.isAfter(_weekStart.add(const Duration(days: 6)))) {
        continue;
      }
      for (final b in _data[ds]!) {
        switch (b.status) {
          case 'approved':
            approved++;
          case 'submitted':
            submitted++;
          case 'new':
            newCount++;
          case 'modified':
            modified++;
          case 'rejected':
            rejected++;
        }
      }
    }
    return {
      'approved': approved,
      'submitted': submitted,
      'new': newCount,
      'modified': modified,
      'rejected': rejected,
    };
  }

  // ─── Overlap Detection ───────────────────────────

  List<(String, String)> _getOverlaps(List<_TimeBlock> blocks) {
    final active = blocks.where((b) => b.status != 'rejected' && !b.pendingDelete).toList();
    final overlaps = <(String, String)>[];
    for (int i = 0; i < active.length; i++) {
      for (int j = i + 1; j < active.length; j++) {
        if (active[i].start < active[j].end && active[i].end > active[j].start) {
          overlaps.add((active[i].id, active[j].id));
        }
      }
    }
    return overlaps;
  }

  // ─── Block Operations ────────────────────────────

  void _addBlock(String dateStr, _TimeBlock block) {
    _data.putIfAbsent(dateStr, () => []);
    _data[dateStr]!.add(block);
    setState(() {});
  }

  void _removeBlock(String dateStr, String blockId) {
    final list = _data[dateStr];
    if (list == null) return;
    final block = list.where((b) => b.id == blockId).firstOrNull;
    if (block == null) return;

    if (block.serverId == null) {
      // 서버에 없는 새 블록은 즉시 삭제
      list.removeWhere((b) => b.id == blockId);
    } else {
      // 서버에 있는 블록은 pendingDelete 표시 (submit 시 서버에서 삭제)
      block.pendingDelete = true;
    }
    if (_selectedBlockId == blockId) _selectedBlockId = null;
    setState(() {});
  }

  void _undoDelete(String dateStr, String blockId) {
    final block = _data[dateStr]?.where((b) => b.id == blockId).firstOrNull;
    if (block != null) {
      block.pendingDelete = false;
      setState(() {});
    }
  }

  void _undoModify(String dateStr, String blockId) {
    final orig = _originals[dateStr]?.where((o) => o.id == blockId).firstOrNull;
    if (orig == null) return;
    final list = _data[dateStr];
    if (list == null) return;
    final idx = list.indexWhere((b) => b.id == blockId);
    if (idx < 0) return;
    list[idx] = orig.copy();
    list[idx].locallyModified = false;
    setState(() {});
  }

  void _updateBlock(String dateStr, _TimeBlock updated) {
    final list = _data[dateStr];
    if (list == null) return;
    final idx = list.indexWhere((b) => b.id == updated.id);
    if (idx >= 0) {
      if (updated.serverId != null) {
        // 원본과 비교해서 같으면 modified 해제
        final dateStr = _data.keys.firstWhere((k) => _data[k] == list);
        final orig = _originals[dateStr]?.where((o) => o.id == updated.id).firstOrNull;
        updated.locallyModified = orig == null ||
            updated.start != orig.start ||
            updated.end != orig.end ||
            updated.storeId != orig.storeId ||
            updated.workRoleId != orig.workRoleId;
      }
      list[idx] = updated;
    }
    setState(() {});
  }

  // ─── Navigation ──────────────────────────────────

  void _prevWeek() {
    setState(() {
      _weekStart = _weekStart.subtract(const Duration(days: 7));
      _selectedBlockId = null;
    });
    _ensureWeekLoaded(_weekStart);
  }

  void _nextWeek() {
    setState(() {
      _weekStart = _weekStart.add(const Duration(days: 7));
      _selectedBlockId = null;
    });
    _ensureWeekLoaded(_weekStart);
  }

  // ─── Submit ──────────────────────────────────────

  /// incomplete 블록 수 (role 미선택)
  int get _incompleteCount {
    int count = 0;
    for (final ds in _data.keys) {
      for (final b in _data[ds]!) {
        if (b.isIncomplete) count++;
      }
    }
    return count;
  }

  /// 변경 사항 계산 (creates, updates, deletes) — incomplete 블록은 제외
  ({
    List<Map<String, dynamic>> creates,
    List<Map<String, dynamic>> updates,
    List<String> deletes,
    int skippedIncomplete,
  }) _calcChanges() {
    final creates = <Map<String, dynamic>>[];
    final updates = <Map<String, dynamic>>[];
    final deletes = <String>[];
    int skippedIncomplete = 0;

    for (final ds in _data.keys) {
      final blocks = _data[ds]!;

      for (final b in blocks) {
        // pendingDelete → 서버 삭제 대상
        if (b.pendingDelete && b.serverId != null) {
          deletes.add(b.serverId!);
          continue;
        }
        if (b.pendingDelete) continue;

        if (b.status == 'new') {
          if (b.isIncomplete) {
            skippedIncomplete++;
            continue;
          }
          creates.add({
            'store_id': b.storeId,
            'work_date': ds,
            'work_role_id': b.workRoleId.isNotEmpty ? b.workRoleId : null,
            'preferred_start_time': _toServerTime(b.start),
            'preferred_end_time': _toServerTime(b.end),
            'note': b.note,
          });
        } else if (b.serverId != null && b.locallyModified) {
          updates.add({
            'id': b.serverId,
            'store_id': b.storeId,
            'work_role_id': b.workRoleId.isNotEmpty ? b.workRoleId : null,
            'preferred_start_time': _toServerTime(b.start),
            'preferred_end_time': _toServerTime(b.end),
            'note': b.note,
          });
        }
      }
    }

    return (creates: creates, updates: updates, deletes: deletes, skippedIncomplete: skippedIncomplete);
  }

  /// 겹침 경고가 있는 날짜 목록
  List<String> _getOverlapDates() {
    final dates = <String>[];
    for (final ds in _data.keys) {
      final overlaps = _getOverlaps(_data[ds]!);
      if (overlaps.isNotEmpty) dates.add(ds);
    }
    return dates;
  }

  Future<void> _submit() async {
    final changes = _calcChanges();
    if (changes.creates.isEmpty && changes.updates.isEmpty && changes.deletes.isEmpty) {
      // 변경사항 없는데 incomplete만 있으면 안내
      if (_incompleteCount > 0) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$_incompleteCount incomplete block(s) without role. Please fix before submitting.')),
          );
        }
      }
      return;
    }

    // Show confirmation dialog
    final overlapDates = _getOverlapDates();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => _SubmitConfirmDialog(
        createCount: changes.creates.length,
        updateCount: changes.updates.length,
        deleteCount: changes.deletes.length,
        overlapDates: overlapDates,
        skippedIncomplete: changes.skippedIncomplete,
      ),
    );
    if (confirmed != true) return;

    setState(() => _isSubmitting = true);
    try {
      await _service.batchSubmit(
        creates: changes.creates,
        updates: changes.updates,
        deletes: changes.deletes,
      );
      // Reload
      _loadedWeeks.clear();
      _data.clear();
      _originals.clear();
      await _ensureWeekLoaded(_weekStart);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Submitted successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Submit failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // ─── Template Save Suggestion ─────────────────────

  Future<void> _showTemplateSaveDialog() async {
    final save = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Save Template'),
        content: const Text('Would you like to save this schedule as a template?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
            child: const Text('Yes', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (save != true || !mounted) return;

    // Build template items from current week data
    final items = <Map<String, dynamic>>[];
    for (final day in _weekDays) {
      final ds = _fmt(day);
      final blocks = _data[ds] ?? [];
      final dayOfWeek = day.weekday % 7; // 0=Sun, 6=Sat
      for (final b in blocks) {
        if (b.status == 'rejected') continue;
        items.add({
          'day_of_week': dayOfWeek,
          'work_role_id': b.workRoleId,
          'preferred_start_time': _toServerTime(b.start),
          'preferred_end_time': _toServerTime(b.end),
        });
      }
    }
    if (items.isEmpty) return;

    try {
      final name = 'Week ${_weekStart.month}/${_weekStart.day}';
      await _service.createTemplate(name: name, isDefault: false, items: items);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Template saved')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save template: $e')),
        );
      }
    }
  }

  Future<void> _createEmptyTemplate() async {
    if (!mounted) return;
    // 바로 편집기 열기 (새 템플릿)
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TemplateEditorSheet(
        service: _service,
        workRoles: _workRoles,
        stores: _stores,
      ),
    );
  }

  // ─── Copy Last Week / Template ────────────────────

  Future<void> _copyLastWeek() async {
    try {
      // 지난 주 데이터 로드
      final prevWeekStart = _weekStart.subtract(const Duration(days: 7));
      final prevDateFrom = _fmt(prevWeekStart);
      final prevDateTo = _fmt(prevWeekStart.add(const Duration(days: 6)));
      final requests = await _service.getMyRequests(dateFrom: prevDateFrom, dateTo: prevDateTo);

      if (requests.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No requests found in the previous week')),
          );
        }
        return;
      }

      // 지난 주 request를 변환하여 공통 중복 처리
      final pendingBlocks = <_PendingBlock>[];
      for (final r in requests) {
        if (r.status == 'rejected') continue;
        final prevDate = r.workDate;
        final dayOffset = prevDate.difference(prevWeekStart).inDays;
        if (dayOffset < 0 || dayOffset > 6) continue;
        final newDate = _weekStart.add(Duration(days: dayOffset));
        double start = 9, end = 17;
        if (r.preferredStartTime != null && r.preferredEndTime != null) {
          final (s, e) = _parseServerTimes(r.preferredStartTime!, r.preferredEndTime!);
          start = s; end = e;
        }
        pendingBlocks.add(_PendingBlock(
          ds: _fmt(newDate), dayOfWeek: newDate.weekday % 7,
          storeId: r.storeId, storeName: r.storeName ?? '',
          workRoleId: r.workRoleId ?? '', workRoleName: r.workRoleName ?? '',
          start: start, end: end,
        ));
      }
      await _addBlocksWithDuplicateCheck(pendingBlocks);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Copy failed: $e')),
        );
      }
    }
  }

  Future<void> _applyTemplate() async {
    List<ScheduleTemplate> templates;
    try {
      templates = await _service.getMyTemplates();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load templates: $e')),
        );
      }
      return;
    }

    if (!mounted) return;

    // 바텀시트로 템플릿 선택
    final selected = await showModalBottomSheet<ScheduleTemplate>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TemplateBottomSheet(
        templates: templates,
        service: _service,
        onDeleted: () {},
        workRoles: _workRoles,
        stores: _stores,
      ),
    );
    if (selected == null) return;

    // 템플릿 items를 이번 주 로컬 블록으로 추가
    final storeId = (selected.storeId != null && selected.storeId!.isNotEmpty)
        ? selected.storeId!
        : (_stores.isNotEmpty ? (_stores.first['id'] ?? '') as String : '');
    final storeName = _stores.isNotEmpty
        ? (_stores.firstWhere((s) => s['id'] == storeId, orElse: () => _stores.first)['name'] ?? '') as String
        : '';

    // 템플릿 items를 변환하여 공통 중복 처리
    final pendingBlocks = <_PendingBlock>[];
    for (final item in selected.items) {
      DateTime? targetDate;
      for (int i = 0; i < 7; i++) {
        final day = _weekStart.add(Duration(days: i));
        if (day.weekday % 7 == item.dayOfWeek) { targetDate = day; break; }
      }
      if (targetDate == null) continue;
      double start = 9, end = 17;
      if (item.preferredStartTime.isNotEmpty && item.preferredEndTime.isNotEmpty) {
        final (s, e) = _parseServerTimes(item.preferredStartTime, item.preferredEndTime);
        start = s; end = e;
      }
      pendingBlocks.add(_PendingBlock(
        ds: _fmt(targetDate), dayOfWeek: targetDate.weekday % 7,
        storeId: storeId, storeName: storeName,
        workRoleId: item.workRoleId, workRoleName: item.workRoleName ?? item.workRoleId,
        start: start, end: end,
      ));
    }
    await _addBlocksWithDuplicateCheck(pendingBlocks);
  }

  /// 블록 추가 + 요일별 중복 체크 (Copy Last Week / Use Template 공통)
  Future<void> _addBlocksWithDuplicateCheck(List<_PendingBlock> blocks) async {
    int added = 0;
    final duplicatesByDay = <int, List<_PendingBlock>>{}; // dayOfWeek → duplicates

    // 1차: 비중복 바로 추가, 중복은 모아두기
    for (final b in blocks) {
      _data.putIfAbsent(b.ds, () => []);
      final existing = _data[b.ds]!.where((e) =>
          !e.pendingDelete && e.status != 'rejected' && e.workRoleId == b.workRoleId).firstOrNull;
      if (existing != null) {
        duplicatesByDay.putIfAbsent(b.dayOfWeek, () => []).add(b);
      } else {
        _data[b.ds]!.add(_TimeBlock(
          id: _genLocalId(), storeId: b.storeId, storeName: b.storeName,
          workRoleId: b.workRoleId, workRoleName: b.workRoleName,
          start: b.start, end: b.end, status: 'new',
        ));
        added++;
      }
    }

    // 2차: 요일별로 중복 처리 물어보기
    int replaced = 0;
    int skipped = 0;
    for (final entry in duplicatesByDay.entries) {
      final dayLabel = _weekdayLabels[entry.key];
      final items = entry.value;
      if (!mounted) break;

      final action = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('$dayLabel — ${items.length} duplicate(s)'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ...items.map((d) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('• ${d.workRoleName}', style: const TextStyle(fontSize: 14)),
              )),
              const SizedBox(height: 8),
              const Text('These roles already exist for this day.', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop('skip'), child: const Text('Skip')),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop('replace'),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
              child: const Text('Replace', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );

      if (action == 'replace') {
        for (final d in items) {
          final existing = _data[d.ds]!.firstWhere((e) =>
              !e.pendingDelete && e.status != 'rejected' && e.workRoleId == d.workRoleId);
          existing.start = d.start;
          existing.end = d.end;
          existing.locallyModified = true;
          replaced++;
        }
      } else {
        skipped += items.length;
      }
    }

    if (mounted) {
      setState(() {});
      final parts = <String>[];
      if (added > 0) parts.add('$added added');
      if (replaced > 0) parts.add('$replaced replaced');
      if (skipped > 0) parts.add('$skipped skipped');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(parts.isEmpty ? 'No changes' : parts.join(', '))),
      );
    }
  }

  void _reloadWeek() {
    _loadedWeeks.remove(_fmt(_weekStart));
    _data.removeWhere((k, _) {
      final d = DateTime.tryParse(k);
      if (d == null) return false;
      return !d.isBefore(_weekStart) && !d.isAfter(_weekStart.add(const Duration(days: 6)));
    });
    _originals.removeWhere((k, _) {
      final d = DateTime.tryParse(k);
      if (d == null) return false;
      return !d.isBefore(_weekStart) && !d.isAfter(_weekStart.add(const Duration(days: 6)));
    });
    _ensureWeekLoaded(_weekStart);
  }

  /// 중복 처리 선택 다이얼로그
  ///
  /// 반환값: "skip" | "replace" | null (취소)
  Future<String?> _showConflictDialog({
    required int createdCount,
    required List skippedItems,
  }) {
    return showDialog<String>(
      context: context,
      builder: (ctx) => _ConflictDialog(
        createdCount: createdCount,
        skippedItems: skippedItems,
      ),
    );
  }

  // ─── Bottom Sheet ────────────────────────────────

  Future<void> _showShiftSheet({
    required String dateStr,
    _TimeBlock? existing,
    double? tapHour,
  }) async {
    final blocksForDate = List<_TimeBlock>.from(_data[dateStr] ?? []);
    final result = await showModalBottomSheet<_TimeBlock>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ShiftBottomSheet(
        stores: _stores,
        workRoles: _workRoles,
        existing: existing,
        defaultStart: tapHour ?? _kDefaultStart,
        dateStr: dateStr,
        existingBlocks: blocksForDate,
      ),
    );
    if (result == null) return;

    if (existing != null) {
      _updateBlock(dateStr, result);
    } else {
      _addBlock(dateStr, result);
    }
  }

  // ─── Build ───────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final weekEnd = _weekStart.add(const Duration(days: 6));
    final counts = _statusCounts;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(weekEnd),
            // Week nav
            _buildWeekNav(weekEnd),
            // Day list
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                itemCount: 7,
                itemBuilder: (context, i) {
                  final day = _weekDays[i];
                  final ds = _fmt(day);
                  final blocks = (_data[ds] ?? [])..sort((a, b) => a.start.compareTo(b.start));
                  final overlaps = _getOverlaps(blocks);
                  return _DaySection(
                    day: day,
                    blocks: blocks,
                    overlaps: overlaps,
                    selectedBlockId: _selectedBlockId,
                    scrollToSelected: _scrollToSelected,
                    onSelectBlock: (id) => setState(() {
                      _selectedBlockId = _selectedBlockId == id ? null : id;
                      _scrollToSelected = false;
                    }),
                    onSelectFromList: (id) => setState(() {
                      _selectedBlockId = _selectedBlockId == id ? null : id;
                      _scrollToSelected = true; // 리스트 탭 = 스크롤
                    }),
                    onAddShift: () => _showShiftSheet(dateStr: ds),
                    onEditBlock: (b) => _showShiftSheet(dateStr: ds, existing: b),
                    onDeleteBlock: (id) => _removeBlock(ds, id),
                    onUndoDelete: (id) => _undoDelete(ds, id),
                    onUndoModify: (id) => _undoModify(ds, id),
                    onBlockResized: (b) => _updateBlock(ds, b),
                    onBlockMoved: (b) => _updateBlock(ds, b),
                    onTapTimeline: (hour) => _showShiftSheet(dateStr: ds, tapHour: hour),
                  );
                },
              ),
            ),
            // Summary bar
            _buildSummaryBar(counts),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(DateTime weekEnd) {
    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const Expanded(
            child: Text(
              'Schedule Request',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
          ),
          // Menu: Copy Last Week, Template
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: AppColors.textSecondary),
            onSelected: (value) {
              switch (value) {
                case 'copy_last':
                  _copyLastWeek();
                case 'template':
                  _applyTemplate();
                case 'save_template':
                  _showTemplateSaveDialog();
                case 'new_template':
                  _createEmptyTemplate();
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'copy_last',
                child: Row(
                  children: [
                    Icon(Icons.content_copy, size: 18, color: AppColors.textSecondary),
                    SizedBox(width: 8),
                    Text('Copy Last Week'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'template',
                child: Row(
                  children: [
                    Icon(Icons.bookmark_outline, size: 18, color: AppColors.textSecondary),
                    SizedBox(width: 8),
                    Text('Use Template'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'save_template',
                child: Row(
                  children: [
                    Icon(Icons.save_outlined, size: 18, color: AppColors.textSecondary),
                    SizedBox(width: 8),
                    Text('Save as Template'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'new_template',
                child: Row(
                  children: [
                    Icon(Icons.add_box_outlined, size: 18, color: AppColors.textSecondary),
                    SizedBox(width: 8),
                    Text('New Template'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWeekNav(DateTime weekEnd) {
    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: _prevWeek,
            child: const Padding(
              padding: EdgeInsets.all(8),
              child: Icon(Icons.chevron_left, size: 20, color: AppColors.textSecondary),
            ),
          ),
          Text(
            '${_weekStart.month}/${_weekStart.day} ~ ${weekEnd.month}/${weekEnd.day}',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          GestureDetector(
            onTap: _nextWeek,
            child: const Padding(
              padding: EdgeInsets.all(8),
              child: Icon(Icons.chevron_right, size: 20, color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryBar(Map<String, int> counts) {
    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          // Status chips
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (counts['approved']! > 0)
                _summaryChip(AppColors.success, '${counts['approved']} approved'),
              if (counts['submitted']! > 0)
                _summaryChip(AppColors.accent, '${counts['submitted']} pending'),
              if (counts['new']! > 0)
                _summaryChip(AppColors.accent, '${counts['new']} new'),
              if (counts['modified']! > 0)
                _summaryChip(AppColors.warning, '${counts['modified']} modified'),
              if (counts['rejected']! > 0)
                _summaryChip(AppColors.danger, '${counts['rejected']} rejected'),
              if (counts.values.every((v) => v == 0))
                const Text('No shifts', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
            ],
          ),
          // Submit button
          if (_hasChanges || _incompleteCount > 0)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _hasChanges && !_isSubmitting ? _submit : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    disabledBackgroundColor: AppColors.border,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Submit', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _summaryChip(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════
// Day Section
// ═══════════════════════════════════════════════════════

class _DaySection extends StatelessWidget {
  final DateTime day;
  final List<_TimeBlock> blocks;
  final List<(String, String)> overlaps;
  final String? selectedBlockId;
  final bool scrollToSelected;
  final ValueChanged<String> onSelectBlock;
  final ValueChanged<String> onSelectFromList; // 리스트에서 선택 → 스크롤
  final VoidCallback onAddShift;
  final ValueChanged<_TimeBlock> onEditBlock;
  final ValueChanged<String> onDeleteBlock;
  final ValueChanged<String> onUndoDelete;
  final ValueChanged<String> onUndoModify;
  final ValueChanged<_TimeBlock> onBlockResized;
  final ValueChanged<_TimeBlock> onBlockMoved;
  final ValueChanged<double> onTapTimeline;

  const _DaySection({
    required this.day,
    required this.blocks,
    required this.overlaps,
    this.selectedBlockId,
    this.scrollToSelected = false,
    required this.onSelectBlock,
    required this.onSelectFromList,
    required this.onAddShift,
    required this.onEditBlock,
    required this.onDeleteBlock,
    required this.onUndoDelete,
    required this.onUndoModify,
    required this.onBlockResized,
    required this.onBlockMoved,
    required this.onTapTimeline,
  });

  bool get _canAddShift {
    // approved만 있는 날(+ rejected)은 추가 숨김
    if (blocks.isEmpty) return true;
    final allApprovedOrRejected =
        blocks.every((b) => b.status == 'approved' || b.status == 'rejected');
    if (allApprovedOrRejected && !blocks.every((b) => b.status == 'rejected')) {
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final wd = day.weekday % 7;
    final isToday = _fmt(day) == _fmt(DateTime.now());
    final overlapIds = <String>{};
    for (final (a, b) in overlaps) {
      overlapIds.add(a);
      overlapIds.add(b);
    }

    // Status badges
    final badgeCounts = <String, int>{};
    for (final b in blocks) {
      badgeCounts[b.status] = (badgeCounts[b.status] ?? 0) + 1;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: isToday ? AppColors.accent : AppColors.border, width: isToday ? 1.5 : 1),
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
                Text(
                  '${day.month}/${day.day}',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isToday ? AppColors.accent : AppColors.text,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  _weekdayLabels[wd],
                  style: TextStyle(
                    fontSize: 13,
                    color: isToday ? AppColors.accent : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: 8),
                ...badgeCounts.entries.map((e) => _statusBadge(e.key, e.value)),
                const Spacer(),
                if (isToday)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('Today', style: TextStyle(color: Colors.white, fontSize: 10)),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            // Timeline
            _TimelineViewport(
              blocks: blocks,
              day: day,
              selectedBlockId: selectedBlockId,
              scrollToSelected: scrollToSelected,
              overlapIds: overlapIds,
              onSelectBlock: onSelectBlock,
              onBlockResized: onBlockResized,
              onBlockMoved: onBlockMoved,
              onTapEmpty: onTapTimeline,
            ),
            // Overlap warning
            if (overlaps.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, size: 14, color: AppColors.danger),
                    const SizedBox(width: 4),
                    Text(
                      'Time overlap',
                      style: TextStyle(fontSize: 12, color: AppColors.danger),
                    ),
                  ],
                ),
              ),
            // Block details
            ...blocks.map((b) => _BlockDetail(
                  block: b,
                  isSelected: b.id == selectedBlockId,
                  isOverlap: overlapIds.contains(b.id),
                  onTap: () => onSelectFromList(b.id),
                  onEdit: b.isEditable ? () => onEditBlock(b) : null,
                  onDelete: b.isEditable ? () => onDeleteBlock(b.id) : null,
                  onUndoDelete: b.pendingDelete ? () => onUndoDelete(b.id) : null,
                  onUndoModify: b.locallyModified && b.serverId != null ? () => onUndoModify(b.id) : null,
                )),
            // Add shift button
            if (_canAddShift)
              GestureDetector(
                onTap: onAddShift,
                child: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_circle_outline, size: 16, color: AppColors.accent),
                      const SizedBox(width: 4),
                      Text(
                        'Add shift',
                        style: TextStyle(fontSize: 13, color: AppColors.accent, fontWeight: FontWeight.w500),
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

  Widget _statusBadge(String status, int count) {
    final color = _blockColor(status);
    return Container(
      margin: const EdgeInsets.only(right: 4),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withAlpha(80), width: 0.5),
      ),
      child: Text(
        count > 1 ? '${_statusLabel(status)} $count' : _statusLabel(status),
        style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w500),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// Timeline Viewport
// ═══════════════════════════════════════════════════════

class _TimelineViewport extends StatefulWidget {
  final List<_TimeBlock> blocks;
  final DateTime day;
  final String? selectedBlockId;
  final bool scrollToSelected; // true일 때만 선택된 블록으로 스크롤
  final Set<String> overlapIds;
  final ValueChanged<String> onSelectBlock;
  final ValueChanged<_TimeBlock> onBlockResized;
  final ValueChanged<_TimeBlock> onBlockMoved;
  final ValueChanged<double> onTapEmpty;

  const _TimelineViewport({
    required this.blocks,
    required this.day,
    this.selectedBlockId,
    this.scrollToSelected = false,
    required this.overlapIds,
    required this.onSelectBlock,
    required this.onBlockResized,
    required this.onBlockMoved,
    required this.onTapEmpty,
  });

  @override
  State<_TimelineViewport> createState() => _TimelineViewportState();
}

class _TimelineViewportState extends State<_TimelineViewport> {
  late ScrollController _scrollCtrl;
  bool _isDragging = false;

  // Drag tooltip state
  String? _dragTooltipText;
  double _dragTooltipX = 0;

  // Drag tracking — 절대좌표 기반 (delta 누적 오차 방지)
  double? _dragStartGlobalX;
  double? _dragStartValue; // block.start or block.end at drag start

  // Block move state
  String? _movingBlockId;
  double? _moveOrigStart;
  double? _moveOrigEnd;

  @override
  void initState() {
    super.initState();
    _scrollCtrl = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToInitial());
  }

  @override
  void didUpdateWidget(covariant _TimelineViewport oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 리스트에서 선택했을 때만 스크롤 (타임라인 탭은 스크롤 안 함)
    if (widget.scrollToSelected &&
        widget.selectedBlockId != null &&
        widget.selectedBlockId != oldWidget.selectedBlockId) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBlock(widget.selectedBlockId!));
    }
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _clearDragTooltip() {
    if (_dragTooltipText != null) {
      setState(() => _dragTooltipText = null);
    }
  }

  void _showDragTooltip(double start, double end, double hourWidth) {
    setState(() {
      _dragTooltipText = '${_fmtHour(start)} ~ ${_fmtHour(end)}';
      _dragTooltipX = (start + end) / 2 * hourWidth;
    });
  }

  void _scrollToBlock(String blockId) {
    if (!_scrollCtrl.hasClients) return;
    final block = widget.blocks.where((b) => b.id == blockId).firstOrNull;
    if (block == null) return;
    final viewportWidth = _scrollCtrl.position.viewportDimension;
    final totalWidth = viewportWidth * _kZoom;
    final hourWidth = totalWidth / _kTimelineHours;
    // 블록 중앙이 뷰포트 중앙에 오도록
    final blockCenter = (block.start + block.end) / 2 * hourWidth;
    final target = (blockCenter - viewportWidth / 2)
        .clamp(0.0, _scrollCtrl.position.maxScrollExtent);
    _scrollCtrl.animateTo(target, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
  }

  void _scrollToInitial() {
    if (!_scrollCtrl.hasClients) return;
    final viewportWidth = _scrollCtrl.position.viewportDimension;
    final totalWidth = viewportWidth * _kZoom;
    final hourWidth = totalWidth / _kTimelineHours;

    double targetHour = 6.0;
    if (widget.blocks.isNotEmpty) {
      final earliest = widget.blocks.map((b) => b.start).reduce(min);
      targetHour = max(0, earliest - 1.5);
    }
    _scrollCtrl.jumpTo((targetHour * hourWidth).clamp(0, _scrollCtrl.position.maxScrollExtent));
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _kTrackHeight + 20 + _kScrollIndicatorHeight + 4,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final viewportWidth = constraints.maxWidth;
          final totalWidth = viewportWidth * _kZoom;
          final hourWidth = totalWidth / _kTimelineHours;

          return Column(
            children: [
              SizedBox(
                height: _kTrackHeight + 20,
                child: SingleChildScrollView(
                  controller: _scrollCtrl,
                  scrollDirection: Axis.horizontal,
                  physics: _isDragging
                      ? const NeverScrollableScrollPhysics()
                      : const ClampingScrollPhysics(),
                  child: GestureDetector(
                    onTapUp: (details) {
                      final hour = details.localPosition.dx / hourWidth;
                      final hitBlock = widget.blocks.where((b) {
                        final bx = b.start * hourWidth;
                        final bw = (b.end - b.start) * hourWidth;
                        return details.localPosition.dx >= bx &&
                            details.localPosition.dx <= bx + bw &&
                            details.localPosition.dy >= 20;
                      }).firstOrNull;
                      if (hitBlock != null) {
                        widget.onSelectBlock(hitBlock.id);
                      } else if (details.localPosition.dy >= 20) {
                        widget.onTapEmpty(_snap(hour));
                      }
                    },
                    child: SizedBox(
                      width: totalWidth,
                      height: _kTrackHeight + 20,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          ..._buildTimeLabels(hourWidth),
                          Positioned(
                            top: 20,
                            left: 0,
                            right: 0,
                            height: _kTrackHeight,
                            child: _buildTrackBg(hourWidth, totalWidth),
                          ),
                          ...widget.blocks.map((b) => _buildBlockBar(b, hourWidth)),
                          // Overlap hatching
                          ..._buildOverlapMarkers(hourWidth),
                          // Drag tooltip
                          if (_dragTooltipText != null)
                            Positioned(
                              top: 0,
                              left: (_dragTooltipX - 45).clamp(0, totalWidth - 90),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.text.withAlpha(220),
                                  borderRadius: BorderRadius.circular(4),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withAlpha(30),
                                      blurRadius: 4,
                                      offset: const Offset(0, 1),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  _dragTooltipText!,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              _buildScrollIndicator(viewportWidth, totalWidth),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _buildTimeLabels(double hourWidth) {
    final labels = <Widget>[];
    final nextDay = widget.day.add(const Duration(days: 1));
    for (int h = 0; h <= _kTimelineHours.floor(); h += 3) {
      String label;
      if (h == 24) {
        label = '${nextDay.month}/${nextDay.day}';
      } else if (h > 24) {
        label = '+${h - 24}';
      } else {
        label = '${h.toString().padLeft(2, '0')}:00';
      }
      labels.add(Positioned(
        left: h * hourWidth - 15,
        top: 0,
        child: SizedBox(
          width: 40,
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 9,
              color: h == 24 ? AppColors.accent : AppColors.textMuted,
              fontWeight: h == 24 ? FontWeight.w700 : FontWeight.normal,
            ),
          ),
        ),
      ));
    }
    return labels;
  }

  Widget _buildTrackBg(double hourWidth, double totalWidth) {
    return CustomPaint(
      size: Size(totalWidth, _kTrackHeight),
      painter: _TrackBgPainter(hourWidth: hourWidth),
    );
  }

  Widget _buildBlockBar(_TimeBlock block, double hourWidth) {
    final left = block.start * hourWidth;
    final width = (block.end - block.start) * hourWidth;
    final isSelected = block.id == widget.selectedBlockId;
    final isOverlap = widget.overlapIds.contains(block.id);
    final isMoving = _movingBlockId == block.id;
    final color = _blockColor(block.status);
    final bgColor = _blockBgColor(block.status);
    final isRejected = block.status == 'rejected';
    final isPendingDelete = block.pendingDelete;
    final isLocallyModified = block.locallyModified && block.serverId != null;
    final isDashed = block.status == 'new' || isLocallyModified;
    // 수정된 블록은 warning 색상
    final effectiveColor = isLocallyModified ? AppColors.warning : color;
    final effectiveBgColor = isLocallyModified ? AppColors.warningBg : bgColor;

    return Positioned(
      top: 20 + 4,
      left: left,
      width: width,
      height: _kTrackHeight - 8,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => widget.onSelectBlock(block.id),
        // 선택된 블록만 드래그 이동 (미선택 블록은 스크롤 패스쓰루)
        onHorizontalDragStart: block.isEditable && isSelected
            ? (d) {
                _movingBlockId = block.id;
                _moveOrigStart = block.start;
                _moveOrigEnd = block.end;
                _dragStartGlobalX = d.globalPosition.dx;
                setState(() => _isDragging = true);
              }
            : null,
        onHorizontalDragUpdate: block.isEditable && isSelected
            ? (d) {
                if (_movingBlockId != block.id) return;
                final dx = d.globalPosition.dx - _dragStartGlobalX!;
                final deltaHours = dx / hourWidth;
                final duration = _moveOrigEnd! - _moveOrigStart!;
                var newStart = _snap5(_moveOrigStart! + deltaHours);
                newStart = newStart.clamp(0.0, _kTimelineHours - duration);
                block.start = newStart;
                block.end = newStart + duration;
                _showDragTooltip(block.start, block.end, hourWidth);
                widget.onBlockMoved(block);
              }
            : null,
        onHorizontalDragEnd: block.isEditable && isSelected
            ? (_) {
                if (_movingBlockId != block.id) return;
                setState(() {
                  _movingBlockId = null;
                  _moveOrigStart = null;
                  _moveOrigEnd = null;
                  _isDragging = false;
                });
                _clearDragTooltip();
                widget.onBlockMoved(block);
              }
            : null,
        child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Main bar
              Opacity(
                opacity: isPendingDelete ? 0.4 : isRejected ? 0.7 : 1.0,
                child: isDashed
                    ? DottedBorder(
                        options: RoundedRectDottedBorderOptions(
                          color: isOverlap ? AppColors.danger : isPendingDelete ? AppColors.danger : effectiveColor,
                          strokeWidth: isOverlap ? 2 : 1.5,
                          radius: const Radius.circular(6),
                          dashPattern: const [5, 3],
                          padding: EdgeInsets.zero,
                        ),
                        child: _blockContent(block, effectiveColor, effectiveBgColor, isPendingDelete, isRejected),
                      )
                    : Container(
                        decoration: BoxDecoration(
                          color: effectiveBgColor,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isOverlap
                                ? AppColors.danger
                                : isSelected || isMoving
                                    ? effectiveColor
                                    : effectiveColor.withAlpha(120),
                            width: isSelected || isOverlap || isMoving ? 2 : 1,
                          ),
                          boxShadow: isMoving
                              ? [BoxShadow(color: effectiveColor.withAlpha(60), blurRadius: 8, offset: const Offset(0, 2))]
                              : null,
                        ),
                        alignment: Alignment.center,
                        child: _blockLabel(block, effectiveColor, isRejected, isPendingDelete),
                      ),
              ),
              // Resize handles (selected + editable, not while moving)
              if (isSelected && block.isEditable && !isMoving) ...[
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onHorizontalDragStart: (d) {
                      setState(() => _isDragging = true);
                      _dragStartGlobalX = d.globalPosition.dx;
                      _dragStartValue = block.start;
                    },
                    onHorizontalDragUpdate: (d) {
                      final dx = d.globalPosition.dx - _dragStartGlobalX!;
                      final newStart = (_dragStartValue! + dx / hourWidth)
                          .clamp(0.0, block.end - _kMinBlockHours);
                      block.start = _snap5(newStart);
                      _showDragTooltip(block.start, block.end, hourWidth);
                      widget.onBlockResized(block);
                    },
                    onHorizontalDragEnd: (_) {
                      block.start = _snap5(block.start);
                      widget.onBlockResized(block);
                      setState(() => _isDragging = false);
                      _dragStartGlobalX = null;
                      _dragStartValue = null;
                      _clearDragTooltip();
                    },
                    child: Container(
                      width: 12,
                      decoration: BoxDecoration(
                        color: effectiveColor,
                        borderRadius: const BorderRadius.horizontal(left: Radius.circular(6)),
                      ),
                      child: const Icon(Icons.drag_handle, size: 10, color: Colors.white),
                    ),
                  ),
                ),
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onHorizontalDragStart: (d) {
                      setState(() => _isDragging = true);
                      _dragStartGlobalX = d.globalPosition.dx;
                      _dragStartValue = block.end;
                    },
                    onHorizontalDragUpdate: (d) {
                      final dx = d.globalPosition.dx - _dragStartGlobalX!;
                      final newEnd = (_dragStartValue! + dx / hourWidth)
                          .clamp(block.start + _kMinBlockHours, _kTimelineHours);
                      block.end = _snap5(newEnd);
                      _showDragTooltip(block.start, block.end, hourWidth);
                      widget.onBlockResized(block);
                    },
                    onHorizontalDragEnd: (_) {
                      block.end = _snap5(block.end);
                      widget.onBlockResized(block);
                      setState(() => _isDragging = false);
                      _dragStartGlobalX = null;
                      _dragStartValue = null;
                      _clearDragTooltip();
                    },
                    child: Container(
                      width: 12,
                      decoration: BoxDecoration(
                        color: effectiveColor,
                        borderRadius: const BorderRadius.horizontal(right: Radius.circular(6)),
                      ),
                      child: const Icon(Icons.drag_handle, size: 10, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ],
          ),
      ),
    );
  }

  Widget _blockContent(_TimeBlock block, Color color, Color bgColor, bool isPendingDelete, bool isRejected) {
    return Container(
      decoration: BoxDecoration(
        color: isPendingDelete ? bgColor.withAlpha(40) : bgColor,
        borderRadius: BorderRadius.circular(4.5),
      ),
      alignment: Alignment.center,
      child: _blockLabel(block, color, isRejected, isPendingDelete),
    );
  }

  Widget _blockLabel(_TimeBlock block, Color color, bool isRejected, bool isPendingDelete) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (block.isIncomplete)
            Padding(
              padding: const EdgeInsets.only(right: 3),
              child: Icon(Icons.warning_amber_rounded, size: 12, color: AppColors.warning),
            ),
          Flexible(
            child: Text(
              block.workRoleName.isNotEmpty
                  ? block.workRoleName
                  : block.isIncomplete
                      ? 'No role'
                      : block.storeName,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                color: block.isIncomplete ? AppColors.warning : isRejected ? color.withAlpha(130) : color,
                fontWeight: FontWeight.w600,
                decoration: isRejected || isPendingDelete ? TextDecoration.lineThrough : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildOverlapMarkers(double hourWidth) {
    final active = widget.blocks.where((b) => b.status != 'rejected' && !b.pendingDelete).toList();
    final markers = <Widget>[];
    for (int i = 0; i < active.length; i++) {
      for (int j = i + 1; j < active.length; j++) {
        final a = active[i], b = active[j];
        if (a.start < b.end && a.end > b.start) {
          final overlapStart = max(a.start, b.start);
          final overlapEnd = min(a.end, b.end);
          markers.add(Positioned(
            top: 20 + 4,
            left: overlapStart * hourWidth,
            width: (overlapEnd - overlapStart) * hourWidth,
            height: _kTrackHeight - 8,
            child: IgnorePointer(
              child: CustomPaint(
                painter: _HatchPainter(),
              ),
            ),
          ));
        }
      }
    }
    return markers;
  }

  Widget _buildScrollIndicator(double viewportWidth, double totalWidth) {
    return AnimatedBuilder(
      animation: _scrollCtrl,
      builder: (context, _) {
        final ratio = viewportWidth / totalWidth;
        final thumbWidth = viewportWidth * ratio;
        double scrollRatio = 0;
        if (_scrollCtrl.hasClients && _scrollCtrl.position.maxScrollExtent > 0) {
          scrollRatio = _scrollCtrl.offset / _scrollCtrl.position.maxScrollExtent;
        }
        final thumbLeft = scrollRatio * (viewportWidth - thumbWidth);

        return Container(
          height: _kScrollIndicatorHeight,
          decoration: BoxDecoration(
            color: AppColors.border,
            borderRadius: BorderRadius.circular(3),
          ),
          child: Stack(
            children: [
              Positioned(
                left: thumbLeft.clamp(0, viewportWidth - thumbWidth),
                width: thumbWidth,
                top: 0,
                bottom: 0,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.textMuted,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── Overlap Hatch Painter ───────────────────────────

class _HatchPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    // 반투명 빨간 배경
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(6)),
      Paint()..color = AppColors.danger.withAlpha(25),
    );
    // 빗금
    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(rect, const Radius.circular(6)));
    final paint = Paint()
      ..color = AppColors.danger.withAlpha(70)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    const gap = 6.0;
    for (double d = -size.height; d < size.width + size.height; d += gap) {
      canvas.drawLine(Offset(d, 0), Offset(d + size.height, size.height), paint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _HatchPainter old) => false;
}

// ─── Track Background Painter ────────────────────────

class _TrackBgPainter extends CustomPainter {
  final double hourWidth;
  _TrackBgPainter({required this.hourWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = const Color(0xFFF8F9FA);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(6)),
      bgPaint,
    );

    // Grid lines
    final lightLine = Paint()
      ..color = const Color(0xFFE5E7EB)
      ..strokeWidth = 0.5;
    final heavyLine = Paint()
      ..color = const Color(0xFFD1D5DB)
      ..strokeWidth = 1;

    for (int h = 0; h <= _kTimelineHours.floor(); h++) {
      final x = h * hourWidth;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        h % 3 == 0 ? heavyLine : lightLine,
      );
    }

    // 24h boundary
    final boundaryPaint = Paint()
      ..color = AppColors.accent
      ..strokeWidth = 1.5;
    final bx = 24 * hourWidth;
    canvas.drawLine(Offset(bx, 0), Offset(bx, size.height), boundaryPaint);

    // Next-day shading (diagonal stripes)
    final shadePaint = Paint()
      ..color = const Color(0x0D000000)
      ..style = PaintingStyle.fill;
    canvas.drawRect(Rect.fromLTWH(bx, 0, size.width - bx, size.height), shadePaint);
  }

  @override
  bool shouldRepaint(covariant _TrackBgPainter old) => old.hourWidth != hourWidth;
}

// ═══════════════════════════════════════════════════════
// Block Detail Row
// ═══════════════════════════════════════════════════════

class _BlockDetail extends StatelessWidget {
  final _TimeBlock block;
  final bool isSelected;
  final bool isOverlap;
  final VoidCallback onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onUndoDelete;
  final VoidCallback? onUndoModify;

  const _BlockDetail({
    required this.block,
    required this.isSelected,
    required this.isOverlap,
    required this.onTap,
    this.onEdit,
    this.onDelete,
    this.onUndoDelete,
    this.onUndoModify,
  });

  @override
  Widget build(BuildContext context) {
    final color = _blockColor(block.status);
    final isRejected = block.status == 'rejected';
    final isServerModified = block.status == 'modified' && !block.locallyModified;
    final isLocallyModified = block.locallyModified && block.serverId != null;
    final isNew = block.status == 'new';
    final isPendingDelete = block.pendingDelete;
    // 수정된 블록은 warning 색상
    final dotColor = isPendingDelete
        ? AppColors.danger
        : isLocallyModified
            ? AppColors.warning
            : color;

    // 상태 라벨
    String? stateTag;
    if (isPendingDelete) {
      stateTag = 'Deleting';
    } else if (isNew) {
      stateTag = 'New';
    } else if (isLocallyModified) {
      stateTag = 'Modified';
    } else if (block.status == 'submitted') {
      stateTag = 'Submitted';
    } else if (block.status == 'approved') {
      stateTag = 'Approved';
    } else if (isServerModified) {
      stateTag = 'Modified';
    } else if (isRejected) {
      stateTag = 'Rejected';
    }

    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: isPendingDelete ? 0.5 : 1.0,
        child: Container(
          margin: const EdgeInsets.only(top: 4),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? _blockBgColor(block.status)
                : isLocallyModified
                    ? AppColors.warningBg.withAlpha(60)
                    : isNew
                        ? AppColors.accentBg.withAlpha(60)
                        : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: isSelected
                ? Border.all(color: dotColor.withAlpha(80), width: 1)
                : null,
          ),
          child: Row(
            children: [
              // Color dot — 상태에 따라 아이콘 변경
              if (isPendingDelete)
                Icon(Icons.remove_circle_outline, size: 14, color: AppColors.danger)
              else if (isNew)
                Icon(Icons.add_circle_outline, size: 14, color: AppColors.accent)
              else if (isLocallyModified)
                Icon(Icons.edit, size: 14, color: AppColors.warning)
              else
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
                ),
              const SizedBox(width: 8),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (block.isIncomplete)
                          Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: Icon(Icons.warning_amber_rounded, size: 14, color: AppColors.warning),
                          ),
                        Flexible(
                          child: Text(
                            block.workRoleName.isNotEmpty
                                ? '${block.storeName} · ${block.workRoleName}'
                                : block.storeName.isNotEmpty
                                    ? '${block.storeName} · (no role)'
                                    : '(incomplete)',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: isPendingDelete
                                  ? AppColors.textMuted
                                  : block.isIncomplete
                                      ? AppColors.warning
                                      : isRejected
                                          ? AppColors.textMuted
                                          : AppColors.text,
                              decoration: isRejected || isPendingDelete ? TextDecoration.lineThrough : null,
                            ),
                          ),
                        ),
                        if (stateTag != null) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: dotColor.withAlpha(20),
                              borderRadius: BorderRadius.circular(3),
                              border: Border.all(color: dotColor.withAlpha(60), width: 0.5),
                            ),
                            child: Text(
                              stateTag,
                              style: TextStyle(fontSize: 9, color: dotColor, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        if (isServerModified && block.origStart != null) ...[
                          Text(
                            '${_fmtHour(block.origStart!)}~${_fmtHour(block.origEnd!)}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textMuted,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                          const Text(' → ', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                        ],
                        Text(
                          '${_fmtHour(block.start)}~${_fmtHour(block.end)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: isRejected ? AppColors.textMuted : AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _fmtDuration(block.hours),
                          style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                    if (isRejected && block.rejectionReason != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          block.rejectionReason!,
                          style: const TextStyle(fontSize: 11, color: AppColors.danger),
                        ),
                      ),
                  ],
                ),
              ),
            // Actions
            if (onUndoDelete != null || onUndoModify != null)
              TextButton.icon(
                onPressed: onUndoDelete ?? onUndoModify,
                icon: const Icon(Icons.undo, size: 16),
                label: const Text('Undo', style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.accent,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 32),
                ),
              ),
            if (onEdit != null)
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 18),
                color: AppColors.textSecondary,
                onPressed: onEdit,
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            if (onDelete != null)
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 18),
                color: AppColors.danger,
                onPressed: onDelete,
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
          ],
        ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// Shift Bottom Sheet (Add/Edit)
// ═══════════════════════════════════════════════════════

class _ShiftBottomSheet extends StatefulWidget {
  final List<Map<String, dynamic>> stores;
  final List<WorkRole> workRoles;
  final _TimeBlock? existing;
  final double defaultStart;
  final String dateStr;
  /// 해당 날짜에 이미 존재하는 블록 목록 (중복 체크용)
  final List<_TimeBlock> existingBlocks;

  const _ShiftBottomSheet({
    required this.stores,
    required this.workRoles,
    this.existing,
    required this.defaultStart,
    required this.dateStr,
    this.existingBlocks = const [],
  });

  @override
  State<_ShiftBottomSheet> createState() => _ShiftBottomSheetState();
}

class _ShiftBottomSheetState extends State<_ShiftBottomSheet> {
  late String _storeId;
  late String _workRoleId;
  late double _start;
  late double _end;
  late String _note;
  late String _storeName;
  late String _workRoleName;
  bool _userSetTime = false; // 유저가 직접 시간을 설정했는지 추적

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      final e = widget.existing!;
      _storeId = e.storeId;
      _storeName = e.storeName;
      _workRoleId = e.workRoleId;
      _workRoleName = e.workRoleName;
      _start = e.start;
      _end = e.end;
      _note = e.note ?? '';
      _userSetTime = true; // 기존 블록 편집 시 시간 보존
    } else {
      _storeId = widget.stores.isNotEmpty ? widget.stores.first['id'] ?? '' : '';
      _storeName = widget.stores.isNotEmpty ? widget.stores.first['name'] ?? '' : '';
      _workRoleId = '';
      _workRoleName = '';
      _start = _snap(widget.defaultStart);
      _end = _snap(widget.defaultStart + _kDefaultBlockHours);
      _note = '';
      // 타임라인 탭으로 열었으면(기본 시작시간이 아니면) 시간 보존
      _userSetTime = widget.defaultStart != _kDefaultStart;
    }
  }

  List<WorkRole> get _filteredRoles =>
      widget.workRoles.where((r) => r.storeId == _storeId && r.isActive).toList();

  void _selectRole(WorkRole role) {
    setState(() {
      _workRoleId = role.id;
      _workRoleName = role.displayName;
      // 유저가 직접 시간을 설정하지 않았을 때만 role 기본 시간 적용
      if (!_userSetTime && role.defaultStartTime != null && role.defaultEndTime != null) {
        final (s, e) = _parseServerTimes(role.defaultStartTime!, role.defaultEndTime!);
        _start = s;
        _end = e;
      }
    });
  }

  void _confirm() {
    if (_storeId.isEmpty) return;

    // 새 블록 추가 시 같은 날 같은 work_role_id 중복 체크
    // rejected 블록은 제외 (다시 신청 가능), 편집 중인 기존 블록도 제외
    if (widget.existing == null && _workRoleId.isNotEmpty) {
      final duplicate = widget.existingBlocks.any((b) =>
          b.workRoleId == _workRoleId &&
          b.status != 'rejected' &&
          !b.pendingDelete);
      if (duplicate) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('이미 해당 역할로 등록된 블록이 있습니다'),
            duration: Duration(seconds: 2),
          ),
        );
        return;
      }
    }

    final block = widget.existing?.copy() ??
        _TimeBlock(
          id: _genLocalId(),
          storeId: '',
          storeName: '',
          workRoleId: '',
          workRoleName: '',
          start: 0,
          end: 0,
          status: 'new',
        );

    block.storeId = _storeId;
    block.storeName = _storeName;
    block.workRoleId = _workRoleId;
    block.workRoleName = _workRoleName;
    block.start = _start;
    block.end = _end;
    block.note = _note.isNotEmpty ? _note : null;

    Navigator.of(context).pop(block);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      margin: const EdgeInsets.only(top: 60),
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  widget.existing != null ? 'Edit Shift' : 'Add Shift',
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 16),

                // Store selection
                const Text('Store', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: widget.stores.map((s) {
                    final sid = s['id'] ?? '';
                    final selected = sid == _storeId;
                    return ChoiceChip(
                      label: Text(s['name'] ?? '', style: TextStyle(fontSize: 13)),
                      selected: selected,
                      onSelected: (_) => setState(() {
                        _storeId = sid;
                        _storeName = s['name'] ?? '';
                        _workRoleId = '';
                        _workRoleName = '';
                      }),
                      selectedColor: AppColors.accentBg,
                      side: BorderSide(color: selected ? AppColors.accent : AppColors.border),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                // Role presets
                if (_filteredRoles.isNotEmpty) ...[
                  Row(
                    children: [
                      const Text('Role', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                      if (_workRoleId.isEmpty) ...[
                        const SizedBox(width: 6),
                        Text('(select a role)',
                          style: TextStyle(fontSize: 11, color: AppColors.warning, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _filteredRoles.map((r) {
                      final selected = r.id == _workRoleId;
                      return GestureDetector(
                        onTap: () => _selectRole(r),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: selected ? AppColors.accentBg : AppColors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: selected ? AppColors.accent : AppColors.border,
                            ),
                          ),
                          child: Column(
                            children: [
                              Text(
                                r.displayName,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: selected ? AppColors.accent : AppColors.text,
                                ),
                              ),
                              if (r.defaultStartTime != null)
                                Text(
                                  '${r.defaultStartTime}~${r.defaultEndTime}',
                                  style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                                ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                ],

                // Time display
                const Text('Time', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _timeInput(_start, (v) => setState(() { _start = v; _userSetTime = true; })),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Text('~', style: TextStyle(fontSize: 16)),
                    ),
                    _timeInput(_end, (v) => setState(() { _end = v; _userSetTime = true; })),
                    const SizedBox(width: 12),
                    Text(
                      _fmtDuration(_end - _start),
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.accent),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Time slider
                RangeSlider(
                  values: RangeValues(_start, _end),
                  min: 0,
                  max: _kTimelineHours,
                  divisions: (_kTimelineHours * 60 / _kSnapMinutes).round(),
                  onChanged: (v) {
                    if (v.end - v.start >= _kMinBlockHours) {
                      setState(() {
                        _start = _snap(v.start);
                        _end = _snap(v.end);
                        _userSetTime = true;
                      });
                    }
                  },
                  activeColor: AppColors.accent,
                  inactiveColor: AppColors.border,
                ),
                const SizedBox(height: 12),

                // Note
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Note (optional)',
                    hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    isDense: true,
                  ),
                  controller: TextEditingController(text: _note),
                  onChanged: (v) => _note = v,
                  style: const TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 20),

                // Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: const BorderSide(color: AppColors.border),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _storeId.isNotEmpty ? _confirm : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('Confirm', style: TextStyle(color: Colors.white)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _timeInput(double value, ValueChanged<double> onChanged) {
    return GestureDetector(
      onTap: () async {
        final hour = value.floor() % 24;
        final minute = ((value % 1) * 60).round();
        final picked = await showTimePicker(
          context: context,
          initialTime: TimeOfDay(hour: hour, minute: minute),
        );
        if (picked != null) {
          var h = picked.hour + picked.minute / 60;
          // If original value was > 24, keep in next-day range
          if (value >= 24 && h < 12) h += 24;
          onChanged(_snap(h));
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          _fmtHour(value),
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// Submit Confirmation Dialog
// ═══════════════════════════════════════════════════════

class _SubmitConfirmDialog extends StatelessWidget {
  final int createCount;
  final int updateCount;
  final int deleteCount;
  final List<String> overlapDates;
  final int skippedIncomplete;

  const _SubmitConfirmDialog({
    required this.createCount,
    required this.updateCount,
    required this.deleteCount,
    required this.overlapDates,
    this.skippedIncomplete = 0,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Submit Schedule'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Changes:', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          if (createCount > 0)
            _changeLine(Icons.add_circle_outline, AppColors.accent, '$createCount new'),
          if (updateCount > 0)
            _changeLine(Icons.edit_outlined, AppColors.warning, '$updateCount modified'),
          if (deleteCount > 0)
            _changeLine(Icons.delete_outline, AppColors.danger, '$deleteCount deleted'),
          if (skippedIncomplete > 0) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.warningBg,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.warning.withAlpha(80)),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, size: 16, color: AppColors.warning),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '$skippedIncomplete incomplete (no role) — excluded from submission',
                      style: TextStyle(fontSize: 12, color: AppColors.warning),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (overlapDates.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.dangerBg,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.danger.withAlpha(80)),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, size: 16, color: AppColors.danger),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${overlapDates.length} day(s) have time overlaps',
                      style: TextStyle(fontSize: 13, color: AppColors.danger),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
          child: const Text('Submit', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }

  Widget _changeLine(IconData icon, Color color, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// Template Bottom Sheet — 템플릿 목록 표시 + 선택/수정/삭제
// ═══════════════════════════════════════════════════════

class _TemplateBottomSheet extends StatefulWidget {
  final List<ScheduleTemplate> templates;
  final ScheduleService service;
  final VoidCallback onDeleted;
  final List<WorkRole> workRoles;
  final List<Map<String, dynamic>> stores;

  const _TemplateBottomSheet({
    required this.templates,
    required this.service,
    required this.onDeleted,
    required this.workRoles,
    required this.stores,
  });

  @override
  State<_TemplateBottomSheet> createState() => _TemplateBottomSheetState();
}

class _TemplateBottomSheetState extends State<_TemplateBottomSheet> {
  late List<ScheduleTemplate> _templates;

  @override
  void initState() {
    super.initState();
    _templates = List.from(widget.templates);
  }

  Future<void> _onEdit(ScheduleTemplate template) async {
    final updated = await showModalBottomSheet<ScheduleTemplate>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TemplateEditorSheet(
        service: widget.service,
        workRoles: widget.workRoles,
        stores: widget.stores,
        existing: template,
      ),
    );
    if (updated != null) {
      setState(() {
        final idx = _templates.indexWhere((t) => t.id == updated.id);
        if (idx != -1) {
          _templates[idx] = updated;
        }
      });
    }
  }

  Future<void> _onDelete(ScheduleTemplate template) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Template'),
        content: Text('Delete "${template.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await widget.service.deleteTemplate(template.id);
      setState(() {
        _templates.removeWhere((t) => t.id == template.id);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 60),
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          const SizedBox(height: 8),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
          // Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const Text(
                  'My Templates',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          const Divider(height: 1),
          // Content
          Flexible(
            child: _templates.isEmpty
                ? _buildEmpty()
                : ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    itemCount: _templates.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, i) => _TemplateCard(
                      template: _templates[i],
                      onUse: () => Navigator.of(context).pop(_templates[i]),
                      onEdit: () => _onEdit(_templates[i]),
                      onDelete: () => _onDelete(_templates[i]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bookmark_border, size: 48, color: AppColors.border),
          const SizedBox(height: 16),
          const Text(
            'No templates yet',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          const Text(
            'Save your current schedule as a template\nfrom the \u22EE menu',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

// ─── Template Card ────────────────────────────────────

class _TemplateCard extends StatelessWidget {
  final ScheduleTemplate template;
  final VoidCallback onUse;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _TemplateCard({
    required this.template,
    required this.onUse,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    // items를 day_of_week 순서로 정렬
    final sortedItems = List.of(template.items)
      ..sort((a, b) => a.dayOfWeek.compareTo(b.dayOfWeek));

    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더 — 이름 + default 뱃지
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    template.name,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
                if (template.isDefault) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.accentBg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'default',
                      style: TextStyle(fontSize: 11, color: AppColors.accent, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ],
            ),
          ),
          // 요일별 항목 요약
          if (sortedItems.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: Text(
                'No items',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: sortedItems.map((item) {
                  final dayLabel = _weekdayLabels[item.dayOfWeek];
                  final roleName = item.workRoleName ?? item.workRoleId;
                  final time = '${item.preferredStartTime}~${item.preferredEndTime}';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 32,
                          child: Text(
                            dayLabel,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            '$roleName  $time',
                            style: const TextStyle(fontSize: 12, color: AppColors.text),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          const Divider(height: 1),
          // 액션 버튼
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: onUse,
                    style: TextButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      minimumSize: const Size(0, 44),
                    ),
                    child: const Text('Use', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: TextButton(
                    onPressed: onEdit,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: const BorderSide(color: AppColors.border),
                      ),
                      minimumSize: const Size(0, 44),
                    ),
                    child: const Text('Edit', style: TextStyle(fontSize: 13)),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: TextButton(
                    onPressed: onDelete,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.danger,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(color: AppColors.danger.withAlpha(80)),
                      ),
                      minimumSize: const Size(0, 44),
                    ),
                    child: const Text('Delete', style: TextStyle(fontSize: 13)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// Template Editor Sheet — 템플릿 항목 편집 (새 생성 / 기존 수정)
// ═══════════════════════════════════════════════════════

class _TemplateEditorSheet extends StatefulWidget {
  final ScheduleService service;
  final List<WorkRole> workRoles;
  final List<Map<String, dynamic>> stores;
  final ScheduleTemplate? existing; // null이면 새 생성

  const _TemplateEditorSheet({
    required this.service,
    required this.workRoles,
    required this.stores,
    this.existing,
  });

  @override
  State<_TemplateEditorSheet> createState() => _TemplateEditorSheetState();
}

class _TemplateEditorSheetState extends State<_TemplateEditorSheet> {
  late TextEditingController _nameCtrl;
  late List<_TemplateEditItem> _items;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.existing?.name ?? '');
    _items = widget.existing?.items.map((e) => _TemplateEditItem(
      dayOfWeek: e.dayOfWeek,
      workRoleId: e.workRoleId,
      workRoleName: e.workRoleName ?? '',
      startTime: e.preferredStartTime,
      endTime: e.preferredEndTime,
    )).toList() ?? [];
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  void _addItem() {
    setState(() {
      _items.add(_TemplateEditItem(dayOfWeek: 0, workRoleId: '', workRoleName: '', startTime: '09:00', endTime: '17:00'));
    });
  }

  void _removeItem(int index) {
    setState(() => _items.removeAt(index));
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a template name')),
      );
      return;
    }
    // workRoleId가 비어있는 항목 제거
    final validItems = _items.where((e) => e.workRoleId.isNotEmpty).toList();

    setState(() => _saving = true);
    try {
      final itemMaps = validItems.map((e) => {
        'day_of_week': e.dayOfWeek,
        'work_role_id': e.workRoleId,
        'preferred_start_time': e.startTime,
        'preferred_end_time': e.endTime,
      }).toList();

      ScheduleTemplate result;
      if (widget.existing != null) {
        result = await widget.service.updateTemplate(
          widget.existing!.id,
          name: name,
          isDefault: widget.existing!.isDefault,
          items: itemMaps,
        );
      } else {
        result = await widget.service.createTemplate(name: name, isDefault: false, items: itemMaps);
      }
      if (mounted) Navigator.of(context).pop(result);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.existing == null;
    return Container(
      margin: const EdgeInsets.only(top: 60),
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(width: 36, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 12),
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Text(isNew ? 'New Template' : 'Edit Template', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                const Spacer(),
                IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => Navigator.of(context).pop(), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
              ],
            ),
          ),
          const Divider(height: 1),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name
                  TextField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(labelText: 'Template Name', border: OutlineInputBorder(), isDense: true),
                  ),
                  const SizedBox(height: 16),
                  // Items header
                  Row(
                    children: [
                      const Text('Shifts', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: _addItem,
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Add'),
                        style: TextButton.styleFrom(foregroundColor: AppColors.accent),
                      ),
                    ],
                  ),
                  if (_items.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text('No shifts yet. Tap "Add" to add one.', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                      ),
                    )
                  else
                    ..._items.asMap().entries.map((entry) {
                      final i = entry.key;
                      final item = entry.value;
                      return _buildItemRow(i, item);
                    }),
                  const SizedBox(height: 20),
                  // Save button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: _saving
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Text(isNew ? 'Create Template' : 'Save Changes', style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemRow(int index, _TemplateEditItem item) {
    final roles = widget.workRoles.where((r) => r.isActive).toList();
    // store별로 그룹핑하여 드롭다운 항목 생성
    final storeNameMap = <String, String>{};
    for (final s in widget.stores) {
      storeNameMap[s['id'] as String] = (s['name'] ?? '') as String;
    }
    final groupedByStore = <String, List<WorkRole>>{};
    for (final r in roles) {
      groupedByStore.putIfAbsent(r.storeId, () => []).add(r);
    }
    final dropdownItems = <DropdownMenuItem<String>>[];
    for (final entry in groupedByStore.entries) {
      final storeName = storeNameMap[entry.key] ?? entry.key;
      // Store 헤더 (선택 불가)
      dropdownItems.add(DropdownMenuItem<String>(
        enabled: false,
        value: '__header_${entry.key}',
        child: Text(storeName, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textMuted)),
      ));
      for (final r in entry.value) {
        dropdownItems.add(DropdownMenuItem<String>(
          value: r.id,
          child: Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Text(r.displayName, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
          ),
        ));
      }
    }

    // 현재 선택된 role의 store 이름
    final selectedRole = roles.where((r) => r.id == item.workRoleId).firstOrNull;
    final selectedStoreName = selectedRole != null ? storeNameMap[selectedRole.storeId] : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          // Store 표시 (선택된 role이 있으면)
          if (selectedStoreName != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Icon(Icons.store, size: 14, color: AppColors.textMuted),
                  const SizedBox(width: 4),
                  Text(selectedStoreName, style: TextStyle(fontSize: 11, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          Row(
            children: [
              // Day dropdown
              SizedBox(
                width: 80,
                child: DropdownButtonFormField<int>(
                  value: item.dayOfWeek,
                  decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
                  items: List.generate(7, (i) => DropdownMenuItem(value: i, child: Text(_weekdayLabels[i], style: const TextStyle(fontSize: 13)))),
                  onChanged: (v) => setState(() => item.dayOfWeek = v ?? 0),
                ),
              ),
              const SizedBox(width: 8),
              // Role dropdown (store별 그룹핑)
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: roles.any((r) => r.id == item.workRoleId) ? item.workRoleId : null,
                  decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8), hintText: 'Role'),
                  isExpanded: true,
                  items: dropdownItems,
                  onChanged: (v) {
                    if (v == null || v.startsWith('__header_')) return;
                    final role = roles.firstWhere((r) => r.id == v);
                    setState(() {
                      item.workRoleId = v;
                      item.workRoleName = role.displayName;
                      if (role.defaultStartTime != null) item.startTime = role.defaultStartTime!;
                      if (role.defaultEndTime != null) item.endTime = role.defaultEndTime!;
                    });
                  },
                ),
              ),
              const SizedBox(width: 4),
              // Delete
              IconButton(
                icon: Icon(Icons.remove_circle_outline, size: 20, color: AppColors.danger),
                onPressed: () => _removeItem(index),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Time
          Row(
            children: [
              const SizedBox(width: 80), // align with day
              const SizedBox(width: 8),
              SizedBox(
                width: 70,
                child: TextFormField(
                  initialValue: item.startTime,
                  decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8), hintText: 'Start'),
                  style: const TextStyle(fontSize: 13),
                  onChanged: (v) => item.startTime = v,
                ),
              ),
              const Padding(padding: EdgeInsets.symmetric(horizontal: 4), child: Text('~', style: TextStyle(fontSize: 14))),
              SizedBox(
                width: 70,
                child: TextFormField(
                  initialValue: item.endTime,
                  decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8), hintText: 'End'),
                  style: const TextStyle(fontSize: 13),
                  onChanged: (v) => item.endTime = v,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TemplateEditItem {
  int dayOfWeek;
  String workRoleId;
  String workRoleName;
  String startTime;
  String endTime;

  _TemplateEditItem({
    required this.dayOfWeek,
    required this.workRoleId,
    required this.workRoleName,
    required this.startTime,
    required this.endTime,
  });
}

// ═══════════════════════════════════════════════════════
// Conflict Dialog — 템플릿/복사 중복 처리 선택
// ═══════════════════════════════════════════════════════

class _ConflictDialog extends StatelessWidget {
  final int createdCount;
  final List skippedItems;

  const _ConflictDialog({
    required this.createdCount,
    required this.skippedItems,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Some items are duplicates'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 요약
            RichText(
              text: TextSpan(
                style: const TextStyle(fontSize: 14, color: AppColors.text),
                children: [
                  TextSpan(
                    text: '$createdCount created',
                    style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.success),
                  ),
                  const TextSpan(text: ', '),
                  TextSpan(
                    text: '${skippedItems.length} skipped',
                    style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.warning),
                  ),
                  const TextSpan(text: ' (already exists)'),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // 건너뛴 항목 상세
            const Text(
              'Skipped items:',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 180),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: skippedItems.length,
                itemBuilder: (_, i) {
                  final item = skippedItems[i] as Map<String, dynamic>? ?? {};
                  final date = item['work_date'] as String? ?? '';
                  final role = item['work_role_name'] as String? ?? item['work_role_id'] as String? ?? '-';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, size: 14, color: AppColors.warning),
                        const SizedBox(width: 6),
                        Text(
                          '$date  $role',
                          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Replace existing requests?',
              style: TextStyle(fontSize: 13, color: AppColors.text),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop('skip'),
          child: const Text('Keep Skipped'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop('replace'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accent,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),
          child: const Text('Replace Existing', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}
