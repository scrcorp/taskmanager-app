/// Tip Entry 입력/수정 — staff app 본인용.
///
/// 모드:
/// - new: 날짜 먼저 선택 → 그 날짜에 schedule 이 있는 매장만 store dropdown 에 노출.
///        schedule 0건이면 "No store scheduled" 안내 + store 선택 비활성 + Submit 차단.
///        work_role 도 schedule 기준으로 prefill (선택 가능).
/// - edit: 기존 entry 데이터 prefill, store/date 잠금.
///
/// 분배 합 > card_tips 면 Submit 차단. 분배 row 는 추가/제거/금액·사유 편집.
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:htm_core/htm_core.dart';

import '../../services/api_client.dart';
import '../../services/tip_service.dart';

/// 특정 날짜의 schedule 옵션 — entry 의 운영 단위.
/// 같은 날 schedule 두 개면 두 옵션 (점심 + 저녁 등).
class _ScheduledOption {
  final String scheduleId;
  final String storeId;
  final String storeName;
  final String? workRoleId;
  final String? workRoleName;
  final String? startTime; // "HH:MM"
  final String? endTime;
  /// 이 schedule 에 이미 entry 가 있으면 true (UNIQUE constraint 회피용 표시).
  final bool alreadySubmitted;
  const _ScheduledOption({
    required this.scheduleId,
    required this.storeId,
    required this.storeName,
    this.workRoleId,
    this.workRoleName,
    this.startTime,
    this.endTime,
    this.alreadySubmitted = false,
  });

  /// Primary label — 시간 먼저 와서 잘려도 핵심 정보 보존.
  /// "21:30–02:00 · barista" 또는 "no time · barista".
  String get primaryLabel {
    final time = (startTime != null && endTime != null)
        ? '$startTime–$endTime'
        : 'no time';
    final role = workRoleName == null || workRoleName!.isEmpty
        ? ''
        : ' · $workRoleName';
    return '$time$role';
  }

  /// Secondary label — 매장 이름 + 상태 (선택용 보조 정보).
  String get secondaryLabel {
    final suffix = alreadySubmitted ? ' · already submitted' : '';
    return '$storeName$suffix';
  }
}

class TipEntryEditorScreen extends ConsumerStatefulWidget {
  /// edit 모드일 때 prefill 용 — null 이면 new 모드.
  final Map<String, dynamic>? initialEntry;
  const TipEntryEditorScreen({super.key, this.initialEntry});

  @override
  ConsumerState<TipEntryEditorScreen> createState() =>
      _TipEntryEditorScreenState();
}

class _DistRow {
  String key;
  String receiverId;
  TextEditingController amountCtrl;
  TextEditingController reasonCtrl;
  _DistRow({
    required this.key,
    this.receiverId = '',
    String amount = '0',
    String reason = '',
  })  : amountCtrl = TextEditingController(text: amount),
        reasonCtrl = TextEditingController(text: reason);
}

class _TipEntryEditorScreenState
    extends ConsumerState<TipEntryEditorScreen> {
  bool get _isEdit => widget.initialEntry != null;

  final _cardCtrl = TextEditingController(text: '0');
  final _cashCtrl = TextEditingController(text: '0');
  String? _scheduleId;
  String? _storeId;
  String? _scheduleLabel; // Edit 모드에서 entry 의 store/work_role 표시용
  DateTime _date = DateTime.now();
  final List<_DistRow> _dists = [];

  /// Add 모드에서 선택된 날짜의 schedule 옵션 (이미 entry 있는 것은 alreadySubmitted=true).
  List<_ScheduledOption> _scheduledOptions = const [];
  bool _loadingSchedule = false;

  List<Map<String, dynamic>> _staff = const [];
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final init = widget.initialEntry;
    if (init != null) {
      _cardCtrl.text = init['card_tips']?.toString() ?? '0';
      _cashCtrl.text = init['cash_tips_kept']?.toString() ?? '0';
      _scheduleId = init['schedule_id']?.toString();
      _storeId = init['store_id']?.toString();
      final storeName = init['store_name']?.toString();
      final roleName = init['work_role_name']?.toString();
      final start = init['schedule_start_time']?.toString();
      final end = init['schedule_end_time']?.toString();
      final time = (start != null && end != null) ? '$start–$end' : null;
      // 시간 · role · @ store 형태로 종합.
      final parts = <String>[];
      if (time != null) parts.add(time);
      if (roleName != null && roleName.isNotEmpty) parts.add(roleName);
      var label = parts.join(' · ');
      if (storeName != null && storeName.isNotEmpty) {
        label = label.isEmpty ? storeName : '$label @ $storeName';
      }
      _scheduleLabel = label.isEmpty ? null : label;
      final dateStr = init['date']?.toString();
      if (dateStr != null) {
        final parts = dateStr.split('-');
        if (parts.length == 3) {
          _date = DateTime(
              int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
        }
      }
      final dList = init['distributions'];
      if (dList is List) {
        for (final d in dList) {
          if (d is Map) {
            _dists.add(_DistRow(
              key: d['id']?.toString() ?? UniqueKey().toString(),
              receiverId: d['receiver_id']?.toString() ?? '',
              amount: d['amount']?.toString() ?? '0',
              reason: d['reason']?.toString() ?? '',
            ));
          }
        }
      }
    }
    _loadLookups();
  }

  String _todayIso() => _isoOf(_date);

  Future<void> _loadLookups() async {
    if (_isEdit) {
      // Edit 모드는 store/date 잠금이므로 schedule 조회 불필요.
      // 분배 picker 용 매장 직원만 로드.
      await _loadStaff();
      setState(() => _loading = false);
      return;
    }
    // Add 모드: 선택된 날짜의 schedule 로 매장 옵션 결정.
    await _loadScheduleForDate();
    setState(() => _loading = false);
  }

  /// 선택된 _date 의 schedule 옵션 로드 + 그 일자 본인 entries 도 조회해서
  /// 이미 제출된 schedule 은 alreadySubmitted=true 로 표시.
  Future<void> _loadScheduleForDate() async {
    setState(() {
      _loadingSchedule = true;
      _error = null;
    });
    final dio = ref.read(dioProvider);
    final service = ref.read(tipServiceProvider);
    final iso = _isoOf(_date);
    try {
      final results = await Future.wait([
        dio.get('/app/my/schedules', queryParameters: {
          'date_from': iso,
          'date_to': iso,
          'per_page': 100,
        }),
        service.listEntries(start: iso, end: iso),
      ]);
      final scheduleRes = results[0] as Response;
      final existingEntries = results[1] as List<Map<String, dynamic>>;

      final data = scheduleRes.data;
      final list = data is Map
          ? (data['items'] ?? data['data'] ?? const [])
          : (data ?? const []);
      // 이미 entry 있는 schedule_id 집합 (Edit 모드의 자기 entry 는 예외 처리).
      final selfEntryId = widget.initialEntry?['id']?.toString();
      final usedScheduleIds = <String>{
        for (final e in existingEntries)
          if (e['schedule_id'] != null && e['id']?.toString() != selfEntryId)
            e['schedule_id'].toString(),
      };

      final options = <_ScheduledOption>[];
      for (final e in list as List) {
        if (e is! Map) continue;
        final st = e['status']?.toString();
        if (st != null && st != 'confirmed') continue;
        final scheduleId = e['id']?.toString();
        if (scheduleId == null || scheduleId.isEmpty) continue;
        options.add(_ScheduledOption(
          scheduleId: scheduleId,
          storeId: e['store_id']?.toString() ?? '',
          storeName: e['store_name']?.toString() ?? '',
          workRoleId: e['work_role_id']?.toString(),
          workRoleName: e['work_role_name']?.toString(),
          startTime: e['start_time']?.toString(),
          endTime: e['end_time']?.toString(),
          alreadySubmitted: usedScheduleIds.contains(scheduleId),
        ));
      }

      setState(() {
        _scheduledOptions = options;
        if (options.isEmpty) {
          _scheduleId = null;
          _storeId = null;
          _staff = const [];
        } else {
          // 기존 선택 유지 시도 (이미 submitted 가 아닌 한). 아니면 첫 가용 옵션.
          final available = options.where((o) => !o.alreadySubmitted).toList();
          final prev = options.firstWhere(
            (o) => o.scheduleId == _scheduleId,
            orElse: () => available.isNotEmpty ? available.first : options.first,
          );
          _scheduleId = prev.scheduleId;
          _storeId = prev.storeId;
        }
        _loadingSchedule = false;
      });
      if (_storeId != null) await _loadStaff();
    } catch (e) {
      setState(() {
        _loadingSchedule = false;
        _error = 'Could not load schedule for this date.';
      });
    }
  }

  String _isoOf(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  Future<void> _loadStaff() async {
    // 분배 대상은 "선택된 schedule 의 같은 매장 + 같은 날 + 시간 overlap" 인 동료로
    // 거른다. eligible-receivers 가 본인을 제외하고 [{id, full_name}] 반환.
    final scheduleId = _scheduleId;
    if (scheduleId == null) {
      setState(() => _staff = const []);
      return;
    }
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.get(
        '/app/my/tips/entries/eligible-receivers',
        queryParameters: {'schedule_id': scheduleId},
      );
      setState(() {
        _staff = (res.data as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      });
    } catch (_) {
      setState(() => _staff = const []);
    }
  }

  double get _card => double.tryParse(_cardCtrl.text) ?? 0;
  double get _cash => double.tryParse(_cashCtrl.text) ?? 0;
  double get _distTotal => _dists.fold<double>(
      0, (s, r) => s + (double.tryParse(r.amountCtrl.text) ?? 0));
  double get _reportableCard => _card - _distTotal;
  double get _reported => _cash + _reportableCard;
  bool get _exceeds => _distTotal > _card;

  void _addDist() {
    setState(() {
      _dists.add(_DistRow(key: UniqueKey().toString()));
    });
  }

  void _removeDist(_DistRow row) {
    setState(() {
      _dists.removeWhere((r) => r.key == row.key);
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 60)),
      lastDate: DateTime.now().add(const Duration(days: 7)),
    );
    if (picked == null) return;
    if (!_isSameDay(picked, _date)) {
      setState(() => _date = picked);
      await _loadScheduleForDate();
    }
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Future<void> _submit() async {
    if (_busy || _exceeds) return;
    if (!_isEdit && _scheduleId == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final service = ref.read(tipServiceProvider);
      final dists = _dists
          .where((d) => d.receiverId.isNotEmpty)
          .map((d) => {
                'receiver_id': d.receiverId,
                'amount': d.amountCtrl.text.trim(),
                'reason':
                    d.reasonCtrl.text.trim().isEmpty ? null : d.reasonCtrl.text.trim(),
              })
          .toList();
      if (_isEdit) {
        await service.updateEntry(
          entryId: widget.initialEntry!['id'] as String,
          cardTips: _card.toStringAsFixed(2),
          cashTipsKept: _cash.toStringAsFixed(2),
          distributions: dists,
        );
      } else {
        await service.createEntry(
          scheduleId: _scheduleId!,
          cardTips: _card.toStringAsFixed(2),
          cashTipsKept: _cash.toStringAsFixed(2),
          distributions: dists,
        );
      }
      if (!mounted) return;
      context.pop();
    } on DioException catch (e) {
      final detail = e.response?.data is Map
          ? (e.response!.data as Map)['detail']?.toString()
          : null;
      setState(() {
        _busy = false;
        _error = detail ?? 'Could not save. Try again.';
      });
    } catch (_) {
      setState(() {
        _busy = false;
        _error = 'Could not save. Try again.';
      });
    }
  }

  @override
  void dispose() {
    _cardCtrl.dispose();
    _cashCtrl.dispose();
    for (final r in _dists) {
      r.amountCtrl.dispose();
      r.reasonCtrl.dispose();
    }
    super.dispose();
  }

  /// Add 모드: 그 날짜 schedule 목록 dropdown.
  /// Edit 모드: entry 의 schedule snapshot 을 read-only.
  Widget _buildStoreWorkRolePicker() {
    if (_isEdit) {
      return _LabelWrap(
        label: 'Schedule',
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(4),
            color: AppColors.bg,
          ),
          child: Text(
            _scheduleLabel ?? '(schedule)',
            style: const TextStyle(fontSize: 14),
          ),
        ),
      );
    }

    if (_loadingSchedule) {
      return _LabelWrap(
        label: 'Schedule',
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(4),
            color: AppColors.white,
          ),
          child: Row(
            children: const [
              SizedBox(
                height: 14,
                width: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 10),
              Text(
                'Looking up your schedule…',
                style: TextStyle(fontSize: 13, color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      );
    }

    if (_scheduledOptions.isEmpty) {
      return _LabelWrap(
        label: 'Schedule',
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(
              color: AppColors.warning.withValues(alpha: 0.5),
            ),
            borderRadius: BorderRadius.circular(8),
            color: AppColors.warning.withValues(alpha: 0.08),
          ),
          child: Row(
            children: const [
              Icon(Icons.info_outline,
                  size: 18, color: AppColors.warning),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'No schedule on this day. Pick another date.',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: AppColors.warning,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final allTaken = _scheduledOptions.every((o) => o.alreadySubmitted);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _LabelWrap(
          label: 'Schedule',
          child: DropdownButtonFormField<String>(
            value: _scheduleId,
            isExpanded: true,
            // 닫힌 상태에서는 primary 한 줄만 — 너비 잘리면 ellipsis.
            selectedItemBuilder: (ctx) => _scheduledOptions
                .map((o) => Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        o.primaryLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ))
                .toList(),
            items: _scheduledOptions
                .map((o) => DropdownMenuItem(
                      value: o.scheduleId,
                      enabled: !o.alreadySubmitted,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            o.primaryLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: o.alreadySubmitted
                                  ? AppColors.textMuted
                                  : AppColors.text,
                            ),
                          ),
                          Text(
                            o.secondaryLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: o.alreadySubmitted
                                  ? AppColors.textMuted
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ))
                .toList(),
            onChanged: (v) async {
              if (v == null) return;
              final picked = _scheduledOptions
                  .firstWhere((o) => o.scheduleId == v);
              if (picked.alreadySubmitted) return;
              setState(() {
                _scheduleId = picked.scheduleId;
                _storeId = picked.storeId;
              });
              // schedule 이 바뀌면 항상 후보 재조회 — 시간/매장 둘 다 영향.
              await _loadStaff();
            },
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ),
        if (allTaken)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'All schedules on this day already have a tip entry. Tap an existing one from the list to edit.',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textMuted,
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit tips' : 'Add tips'),
        backgroundColor: AppColors.white,
      ),
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Date (먼저 선택) ────────────────────────────
            _LabelWrap(
              label: 'Date',
              child: InkWell(
                onTap: _isEdit ? null : _pickDate,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(4),
                    color: _isEdit ? AppColors.bg : AppColors.white,
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today,
                          size: 16, color: AppColors.textMuted),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _todayIso(),
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                      if (!_isEdit)
                        const Icon(Icons.arrow_drop_down,
                            size: 18, color: AppColors.textMuted),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // ── Store / Work role (날짜에 schedule 이 있어야 표시) ──
            _buildStoreWorkRolePicker(),
            const SizedBox(height: 16),

            // Card / Cash
            _MoneyField(label: 'Card tips (gross)', controller: _cardCtrl, onChanged: (_) => setState(() {})),
            const SizedBox(height: 12),
            _MoneyField(label: 'Cash kept', controller: _cashCtrl, onChanged: (_) => setState(() {})),

            const SizedBox(height: 20),

            // Distributions
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Card distributions',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
                  ),
                ),
                TextButton.icon(
                  onPressed: _addDist,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add'),
                ),
              ],
            ),
            if (_dists.isEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'No distributions. All card tips will be reported.',
                  style:
                      TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
              ),
            ..._dists.map((row) => _DistRowWidget(
                  row: row,
                  staff: _staff,
                  takenByOthers: _dists
                      .where((r) => r.key != row.key && r.receiverId.isNotEmpty)
                      .map((r) => r.receiverId)
                      .toSet(),
                  onChanged: () => setState(() {}),
                  onRemove: () => _removeDist(row),
                )),

            const SizedBox(height: 20),

            // Calculation
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _CalcRow(label: 'Cash kept', value: _cash),
                  _CalcRow(
                      label: 'Distributed',
                      value: _distTotal,
                      tone: _exceeds ? _CalcTone.danger : null),
                  _CalcRow(
                      label: 'Reportable card',
                      value: _reportableCard,
                      tone: _exceeds ? _CalcTone.danger : null),
                  const Divider(height: 16),
                  _CalcRow(
                      label: 'Reported on 4070',
                      value: _reported,
                      bold: true,
                      tone: _CalcTone.accent),
                ],
              ),
            ),
            if (_exceeds) ...[
              const SizedBox(height: 8),
              Text(
                'Distributed exceeds card tips by \$${(_distTotal - _card).toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.danger,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: const TextStyle(
                  color: AppColors.danger,
                  fontSize: 12,
                ),
              ),
            ],
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _busy ||
                      _exceeds ||
                      (!_isEdit && _scheduleId == null)
                  ? null
                  : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _busy
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      _isEdit ? 'Save changes' : 'Add entry',
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700),
                    ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class _LabelWrap extends StatelessWidget {
  final String label;
  final Widget child;
  const _LabelWrap({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.textMuted,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 4),
        child,
      ],
    );
  }
}

class _MoneyField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  const _MoneyField({
    required this.label,
    required this.controller,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return _LabelWrap(
      label: label,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        keyboardType:
            const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
        ],
        decoration: const InputDecoration(
          prefixText: '\$ ',
          border: OutlineInputBorder(),
          isDense: true,
        ),
      ),
    );
  }
}

class _DistRowWidget extends StatelessWidget {
  final _DistRow row;
  final List<Map<String, dynamic>> staff;
  /// 다른 row 들이 이미 선택한 receiver_id 들 — 이 row 의 dropdown 에서 제외.
  final Set<String> takenByOthers;
  final VoidCallback onChanged;
  final VoidCallback onRemove;
  const _DistRowWidget({
    required this.row,
    required this.staff,
    required this.takenByOthers,
    required this.onChanged,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    // 본 row 의 현재 selection 은 유지하되, 다른 row 가 점유한 것만 빼고 노출.
    final available = staff
        .where((s) =>
            !takenByOthers.contains(s['id'] as String) ||
            (s['id'] as String) == row.receiverId)
        .toList();
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: row.receiverId.isEmpty ? null : row.receiverId,
                  items: available
                      .map((s) => DropdownMenuItem(
                            value: s['id'] as String,
                            child: Text(s['full_name'] as String),
                          ))
                      .toList(),
                  onChanged: (v) {
                    row.receiverId = v ?? '';
                    onChanged();
                  },
                  decoration: InputDecoration(
                    hintText: available.isEmpty
                        ? 'No eligible coworker'
                        : 'Select coworker',
                    isDense: true,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline,
                    color: AppColors.danger, size: 20),
                onPressed: onRemove,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              SizedBox(
                width: 100,
                child: TextField(
                  controller: row.amountCtrl,
                  onChanged: (_) => onChanged(),
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                  decoration: const InputDecoration(
                    prefixText: '\$ ',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: row.reasonCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Reason (optional)',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

enum _CalcTone { accent, danger }

class _CalcRow extends StatelessWidget {
  final String label;
  final double value;
  final bool bold;
  final _CalcTone? tone;
  const _CalcRow({
    required this.label,
    required this.value,
    this.bold = false,
    this.tone,
  });

  @override
  Widget build(BuildContext context) {
    final color = tone == _CalcTone.danger
        ? AppColors.danger
        : tone == _CalcTone.accent
            ? AppColors.accent
            : AppColors.text;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: bold ? color : AppColors.textSecondary,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
          Text(
            '\$${value.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: bold ? 16 : 13,
              color: color,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
