/// Clock-out 직후 팁 입력 화면 (매장 비치 태블릿).
///
/// Stage A: card_tips + cash_tips_kept 두 필드만. 동료 분배는 staff app 에서
/// 추가/수정 (이 화면에서는 단순화). "No tips today — Skip & Continue" 로
/// 건너뛸 수 있다.
///
/// 진입: AttendancePinScreen 이 clock-out 성공한 직후 pushReplacement.
/// 종료: Submit 또는 Skip 후 AttendanceSuccessScreen 으로 pushReplacement.
///
/// PIN 은 AttendancePinScreen 에서 검증되었지만 tip-entry API 가 server 측에서
/// 다시 검증한다 (같은 PIN 그대로 전달).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:htm_core/htm_core.dart';

import '../../services/attendance_device_service.dart';
import 'attendance_main_screen.dart';
import 'attendance_success_screen.dart';

class AttendanceTipEntryScreen extends ConsumerStatefulWidget {
  final String userId;
  final String userName;
  final String pin;
  final int? workedMinutes;

  const AttendanceTipEntryScreen({
    super.key,
    required this.userId,
    required this.userName,
    required this.pin,
    this.workedMinutes,
  });

  @override
  ConsumerState<AttendanceTipEntryScreen> createState() =>
      _AttendanceTipEntryScreenState();
}

class _KioskDistRow {
  String receiverId = '';
  final TextEditingController amountCtrl = TextEditingController();
  final String key;
  _KioskDistRow() : key = UniqueKey().toString();
  void dispose() {
    amountCtrl.dispose();
  }
}

class _AttendanceTipEntryScreenState
    extends ConsumerState<AttendanceTipEntryScreen> {
  // 빈 시작값 — 사용자가 0 을 지우는 마찰 제거. UI 에 prefix '$' + placeholder '0.00'.
  final _cardCtrl = TextEditingController();
  final _cashCtrl = TextEditingController();
  final List<_KioskDistRow> _dists = [];
  /// 분배 후보. PIN 인증 후 한 번만 fetch.
  List<Map<String, dynamic>> _eligibleReceivers = const [];
  bool _loadingReceivers = true;
  bool _busy = false;
  String? _errorMessage;

  double get _card => double.tryParse(_cardCtrl.text) ?? 0;
  double get _cash => double.tryParse(_cashCtrl.text) ?? 0;
  double get _distTotal => _dists.fold<double>(
      0, (s, r) => s + (double.tryParse(r.amountCtrl.text) ?? 0));
  double get _reported => _card + _cash;
  bool get _exceeds => _distTotal > _card;

  @override
  void initState() {
    super.initState();
    _loadReceivers();
  }

  Future<void> _loadReceivers() async {
    try {
      final service = ref.read(attendanceDeviceServiceProvider);
      final list = await service.getTipEligibleReceivers(
        userId: widget.userId,
        pin: widget.pin,
      );
      if (!mounted) return;
      setState(() {
        _eligibleReceivers = list;
        _loadingReceivers = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _eligibleReceivers = const [];
        _loadingReceivers = false;
      });
    }
  }

  void _addDist() {
    setState(() => _dists.add(_KioskDistRow()));
  }

  void _removeDist(_KioskDistRow row) {
    setState(() {
      _dists.removeWhere((r) => r.key == row.key);
      row.dispose();
    });
  }

  String _todayIso() {
    final n = DateTime.now();
    return '${n.year.toString().padLeft(4, '0')}-'
        '${n.month.toString().padLeft(2, '0')}-'
        '${n.day.toString().padLeft(2, '0')}';
  }

  void _gotoSuccess() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => AttendanceSuccessScreen(
          action: AttendanceAction.clockOut,
          userName: widget.userName,
          workedMinutes: widget.workedMinutes,
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (_busy) return;
    if (_exceeds) {
      setState(() => _errorMessage =
          'Distributed exceeds card tips by \$${(_distTotal - _card).toStringAsFixed(2)}');
      return;
    }
    // 분배 row 검증 — receiver 미선택 또는 amount 비어있는 row 는 거부.
    for (final r in _dists) {
      if (r.receiverId.isEmpty) {
        setState(() => _errorMessage = 'Each distribution row needs a coworker.');
        return;
      }
      if ((double.tryParse(r.amountCtrl.text) ?? 0) <= 0) {
        setState(() => _errorMessage = 'Each distribution row needs an amount.');
        return;
      }
    }

    setState(() {
      _busy = true;
      _errorMessage = null;
    });
    try {
      final service = ref.read(attendanceDeviceServiceProvider);
      await service.submitTipEntry(
        userId: widget.userId,
        pin: widget.pin,
        date: _todayIso(),
        cardTips: _card.toStringAsFixed(2),
        cashTipsKept: _cash.toStringAsFixed(2),
        distributions: _dists
            .map((r) => {
                  'receiver_id': r.receiverId,
                  'amount': (double.tryParse(r.amountCtrl.text) ?? 0)
                      .toStringAsFixed(2),
                })
            .toList(),
      );
      _gotoSuccess();
    } catch (e) {
      setState(() {
        _busy = false;
        _errorMessage = _humanError(e);
      });
    }
  }

  String _humanError(Object e) {
    final s = e.toString();
    if (s.contains('Distributed exceeds')) {
      return s.substring(s.indexOf('Distributed'));
    }
    return 'Could not save tip entry. Try again or skip for now.';
  }

  @override
  void dispose() {
    _cardCtrl.dispose();
    _cashCtrl.dispose();
    for (final r in _dists) {
      r.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.payments_outlined,
                          color: AppColors.accent, size: 28),
                      const SizedBox(width: 10),
                      Text(
                        'Report tips',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: AppColors.text,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${widget.userName} · ${_todayIso()}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _MoneyField(
                    label: 'Total credit-card tips',
                    helper: 'Gross amount before sharing with coworkers',
                    controller: _cardCtrl,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 16),
                  _MoneyField(
                    label: 'Cash tips kept',
                    helper: 'After splitting with coworkers in person',
                    controller: _cashCtrl,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        vertical: 12, horizontal: 14),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Reported on 4070',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        Text(
                          '\$${_reported.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppColors.accent,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Split card tips with coworkers — or skip and edit later in the staff app.',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // ── 분배 섹션 ─────────────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Distributions',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.text,
                        ),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Add'),
                        onPressed: (_loadingReceivers || _busy ||
                                _eligibleReceivers.length <= _dists.length)
                            ? null
                            : _addDist,
                      ),
                    ],
                  ),
                  if (_loadingReceivers)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'Loading coworkers…',
                        style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                      ),
                    )
                  else if (_eligibleReceivers.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.bg,
                        border: Border.all(color: AppColors.border),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'No coworkers worked your hours today. You can edit later in the staff app.',
                        style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                      ),
                    )
                  else if (_dists.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.bg,
                        border: Border.all(color: AppColors.border),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'No distributions. All card tips will be reported.',
                        style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                      ),
                    )
                  else
                    ..._dists.map((row) {
                      final takenByOthers = _dists
                          .where((r) => r.key != row.key && r.receiverId.isNotEmpty)
                          .map((r) => r.receiverId)
                          .toSet();
                      final available = _eligibleReceivers
                          .where((r) =>
                              !takenByOthers.contains(r['id'] as String) ||
                              (r['id'] as String) == row.receiverId)
                          .toList();
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            border: Border.all(color: AppColors.border),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
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
                                  onChanged: (v) => setState(() {
                                    row.receiverId = v ?? '';
                                  }),
                                  decoration: const InputDecoration(
                                    hintText: 'Select coworker',
                                    isDense: true,
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 110,
                                child: TextField(
                                  controller: row.amountCtrl,
                                  onChanged: (_) => setState(() {}),
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                          decimal: true),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(
                                        RegExp(r'[0-9.]')),
                                  ],
                                  decoration: const InputDecoration(
                                    prefixText: '\$ ',
                                    isDense: true,
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline,
                                    color: AppColors.danger, size: 22),
                                onPressed: () => _removeDist(row),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  if (_dists.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Distributed', style: TextStyle(fontSize: 12)),
                          Text(
                            '\$${_distTotal.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: _exceeds ? AppColors.danger : AppColors.text,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_exceeds)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Distributed exceeds card tips by \$${(_distTotal - _card).toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.danger,
                          ),
                        ),
                      ),
                  ],
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.danger.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.danger,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _busy ? null : _gotoSuccess,
                          style: OutlinedButton.styleFrom(
                            padding:
                                const EdgeInsets.symmetric(vertical: 16),
                            side:
                                const BorderSide(color: AppColors.border),
                          ),
                          child: const Text(
                            'No tips — Skip & Continue',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: _busy ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accent,
                            foregroundColor: Colors.white,
                            padding:
                                const EdgeInsets.symmetric(vertical: 16),
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
                              : const Text(
                                  'Submit & Continue',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MoneyField extends StatelessWidget {
  final String label;
  final String helper;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const _MoneyField({
    required this.label,
    required this.helper,
    required this.controller,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            helper,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Text(
                '\$',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: TextField(
                  controller: controller,
                  onChanged: onChanged,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                        RegExp(r'[0-9.]')),
                  ],
                  decoration: const InputDecoration(
                    hintText: '0.00',
                    hintStyle: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textMuted,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text,
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
