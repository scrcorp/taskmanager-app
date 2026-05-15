/// Tips 메인 화면 — Period 누적 요약 + Pending 분배.
///
/// Stage A 단순 구성:
/// - 상단: 현재 사이클 요약 카드 (Reported on 4070 · Card · Cash · Distributed · Received)
/// - 받은 분배 — pending 카드 리스트 ("Confirm OK" 버튼)
/// - 일별 entries 리스트 (Daily Entry 화면으로 진입)
///
/// 사이클 = 반월(1-15 / 16-EOM). 현재 사이클 자동 계산.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:htm_core/htm_core.dart';

import '../../services/tip_service.dart';

String _pad2(int n) => n.toString().padLeft(2, '0');

class _CyclePeriod {
  final DateTime start;
  final DateTime end;
  const _CyclePeriod(this.start, this.end);

  String get startIso =>
      '${start.year}-${_pad2(start.month)}-${_pad2(start.day)}';
  String get endIso => '${end.year}-${_pad2(end.month)}-${_pad2(end.day)}';

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  String get label =>
      '${_months[start.month - 1]} ${start.day} – ${_months[end.month - 1]} ${end.day}';

  String get shortLabel => '${_months[start.month - 1]} ${start.day}–${end.day}';

  String get key => '${start.toIso8601String()}_${end.toIso8601String()}';

  bool get isCurrent {
    final now = DateTime.now();
    return !now.isBefore(start) && !now.isAfter(end);
  }

  static _CyclePeriod current() => of(DateTime.now());

  /// 주어진 날짜가 속한 반월 사이클.
  static _CyclePeriod of(DateTime d) {
    if (d.day <= 15) {
      return _CyclePeriod(
        DateTime(d.year, d.month, 1),
        DateTime(d.year, d.month, 15),
      );
    }
    final lastDay = DateTime(d.year, d.month + 1, 0).day;
    return _CyclePeriod(
      DateTime(d.year, d.month, 16),
      DateTime(d.year, d.month, lastDay),
    );
  }

  /// 최근 N개 (현재 포함, 과거 순).
  static List<_CyclePeriod> recent(int count) {
    final out = <_CyclePeriod>[];
    var cursor = DateTime.now();
    for (var i = 0; i < count; i++) {
      final p = _CyclePeriod.of(cursor);
      out.add(p);
      // 이전 사이클의 마지막 날 = start - 1day
      cursor = p.start.subtract(const Duration(days: 1));
    }
    return out;
  }
}

class TipsHomeScreen extends ConsumerStatefulWidget {
  const TipsHomeScreen({super.key});

  @override
  ConsumerState<TipsHomeScreen> createState() => _TipsHomeScreenState();
}

class _TipsHomeScreenState extends ConsumerState<TipsHomeScreen> {
  late _CyclePeriod _period;
  List<Map<String, dynamic>> _entries = const [];
  /// 모든 incoming (pending + accepted + auto_accepted).
  List<Map<String, dynamic>> _incoming = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _period = _CyclePeriod.current();
    _load();
  }

  /// 현재 사이클 안에 들어오는 incoming 만 필터 (created_at 또는 work_date 기준).
  List<Map<String, dynamic>> get _periodIncoming {
    bool inRange(Map<String, dynamic> d) {
      final wd = d['work_date']?.toString();
      if (wd == null) return false;
      return wd.compareTo(_period.startIso) >= 0 &&
          wd.compareTo(_period.endIso) <= 0;
    }
    return _incoming.where(inRange).toList();
  }

  List<Map<String, dynamic>> get _pending =>
      _incoming.where((d) => d['status'] == 'pending').toList();

  List<Map<String, dynamic>> get _receivedHistory =>
      _periodIncoming
          .where((d) => d['status'] == 'accepted' || d['status'] == 'auto_accepted')
          .toList()
        ..sort((a, b) => (b['accepted_at'] ?? b['created_at'] ?? '')
            .toString()
            .compareTo((a['accepted_at'] ?? a['created_at'] ?? '').toString()));

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final service = ref.read(tipServiceProvider);
      final results = await Future.wait([
        service.listEntries(start: _period.startIso, end: _period.endIso),
        service.listIncoming(), // 모든 status — 클라이언트가 분할
      ]);
      if (!mounted) return;
      setState(() {
        _entries = results[0];
        _incoming = results[1];
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load tip data. Pull down to retry.';
        _loading = false;
      });
    }
  }

  void _pickPeriod() async {
    final options = _CyclePeriod.recent(8);
    final picked = await showModalBottomSheet<_CyclePeriod>(
      context: context,
      builder: (ctx) => ListView(
        shrinkWrap: true,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Select cycle',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppColors.text,
              ),
            ),
          ),
          for (final p in options)
            ListTile(
              dense: true,
              selected: p.key == _period.key,
              title: Text(p.label),
              trailing: p.isCurrent
                  ? const Text(
                      'CURRENT',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.success,
                      ),
                    )
                  : null,
              onTap: () => Navigator.pop(ctx, p),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
    if (picked != null && picked.key != _period.key) {
      setState(() => _period = picked);
      await _load();
    }
  }

  double _sumField(List<Map<String, dynamic>> rows, String field) {
    double s = 0;
    for (final r in rows) {
      final v = r[field];
      if (v is String) s += double.tryParse(v) ?? 0;
      if (v is num) s += v.toDouble();
    }
    return s;
  }

  Future<void> _accept(String id) async {
    try {
      await ref.read(tipServiceProvider).acceptDistribution(id);
      await _load();
    } catch (e) {
      if (!mounted) return;
      await AppModal.show(
        context,
        title: "Couldn't confirm",
        message:
            'Could not confirm this tip. Check your connection and try again, or ask your manager.',
        type: ModalType.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final reported = _sumField(_entries, 'reported_on_4070');
    // Card = 분배 차감 후 본인 신고용 카드 (reportable_card 합).
    final reportableCard = _sumField(_entries, 'reportable_card');
    final cash = _sumField(_entries, 'cash_tips_kept');
    // Received = 받은 분배 (period 안, 모든 status). 신고용 box2 의 일부.
    final received = _periodIncoming.fold<double>(
      0,
      (s, d) => s + (double.tryParse(d['amount']?.toString() ?? '0') ?? 0),
    );
    final pendingIn = _pending.fold<double>(
      0,
      (s, d) => s + (double.tryParse(d['amount']?.toString() ?? '0') ?? 0),
    );

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          if (_loading && _entries.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 80),
              child: Center(child: CircularProgressIndicator()),
            ),
          if (_error != null)
            _ErrorBanner(message: _error!, onRetry: _load),

          // ── Period selector pill
          Align(
            alignment: Alignment.centerLeft,
            child: InkWell(
              onTap: _pickPeriod,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.calendar_today,
                        size: 13, color: AppColors.textMuted),
                    const SizedBox(width: 6),
                    Text(
                      _period.label,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text,
                      ),
                    ),
                    if (_period.isCurrent) ...[
                      const SizedBox(width: 6),
                      const Text(
                        '· current',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.success,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const SizedBox(width: 4),
                    const Icon(Icons.arrow_drop_down,
                        size: 16, color: AppColors.textMuted),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // ── Hero card
          _PeriodHeroCard(
            label: _period.label,
            reported: reported,
            entriesCount: _entries.length,
          ),
          const SizedBox(height: 12),

          // ── 4 stats
          // Card = 분배 차감 후 본인 신고용 카드 (Card after sharing).
          // Cash kept = 본인 현금몫 그대로.
          // Received = 동료에게 받은 분배 합 (period 안, 모든 status).
          // Pending in = 아직 OK 처리 안 한 분배 합 (Received 의 부분집합 표시용).
          Row(
            children: [
              Expanded(child: _StatTile(label: 'Card', value: reportableCard)),
              const SizedBox(width: 8),
              Expanded(child: _StatTile(label: 'Cash kept', value: cash)),
              const SizedBox(width: 8),
              Expanded(child: _StatTile(label: 'Received', value: received)),
              const SizedBox(width: 8),
              Expanded(
                  child: _StatTile(label: 'Pending in', value: pendingIn)),
            ],
          ),
          const SizedBox(height: 20),

          // ── Pending 분배 (OK 처리 대기)
          if (_pending.isNotEmpty) ...[
            const _SectionHeader(
              title: 'Pending tips',
              subtitle:
                  'Tap OK to confirm. If wrong, see your manager. Auto-confirmed in 24h.',
            ),
            const SizedBox(height: 8),
            ..._pending.map((d) => _PendingCard(
                  dist: d,
                  onAccept: () => _accept(d['id'] as String),
                )),
            const SizedBox(height: 20),
          ],

          // ── 받은 내역 (이미 OK 처리된 분배 + auto)
          if (_receivedHistory.isNotEmpty) ...[
            const _SectionHeader(
              title: 'Received',
              subtitle: 'Tips coworkers sent you this cycle.',
            ),
            const SizedBox(height: 8),
            ..._receivedHistory.map((d) => _ReceivedRow(dist: d)),
            const SizedBox(height: 20),
          ],

          // ── Daily entries
          const _SectionHeader(
            title: 'Daily entries',
            subtitle: 'Tap a day to add or edit.',
          ),
          const SizedBox(height: 8),
          if (!_loading && _entries.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: const Text(
                'No tip entries yet this cycle.\nUse the attendance station after clock-out or tap "+ Add entry" below to enter manually.',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
            ),
          ..._entries.map(
            (e) => _EntryRow(
              entry: e,
              onTap: () => context.push(
                '/tips/edit/${e['id']}',
                extra: e,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: TextButton.icon(
              onPressed: () => context.push('/tips/new'),
              icon: const Icon(Icons.add, color: AppColors.accent),
              label: const Text(
                'Add entry manually',
                style: TextStyle(
                  color: AppColors.accent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => context.push('/tips/forms'),
            icon: const Icon(Icons.description_outlined, size: 18),
            label: const Text(
              'IRS Form 4070',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.accent,
              side: const BorderSide(color: AppColors.border),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
          const SizedBox(height: 60),
        ],
      ),
    );
  }
}

class _PeriodHeroCard extends StatelessWidget {
  final String label;
  final double reported;
  final int entriesCount;
  const _PeriodHeroCard({
    required this.label,
    required this.reported,
    required this.entriesCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.accent,
            AppColors.accent.withValues(alpha: 0.7),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '\$${reported.toStringAsFixed(2)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Reported on 4070 (so far) · $entriesCount entries',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final double value;
  const _StatTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: AppColors.textMuted,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '\$${value.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.text,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  const _SectionHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.text,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
        ),
      ],
    );
  }
}

class _PendingCard extends StatelessWidget {
  final Map<String, dynamic> dist;
  final VoidCallback onAccept;
  const _PendingCard({required this.dist, required this.onAccept});

  String _autoAcceptHint(String? iso) {
    if (iso == null) return '';
    final target = DateTime.tryParse(iso);
    if (target == null) return '';
    final diff = target.difference(DateTime.now());
    if (diff.isNegative) return 'Auto-confirming…';
    final h = diff.inHours;
    final m = diff.inMinutes % 60;
    if (h >= 1) return 'Auto in ${h}h ${m}m';
    return 'Auto in ${diff.inMinutes}m';
  }

  @override
  Widget build(BuildContext context) {
    final sender = dist['sender_name']?.toString() ?? '—';
    final amt = double.tryParse(dist['amount']?.toString() ?? '0') ?? 0;
    final reason = dist['reason']?.toString();
    final date = dist['work_date']?.toString() ?? '';
    final autoHint = _autoAcceptHint(dist['pending_until']?.toString());
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'From $sender',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      date + (reason == null || reason.isEmpty ? '' : ' · $reason'),
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '\$${amt.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.accent,
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: onAccept,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                child: const Text(
                  'Confirm OK',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              if (autoHint.isNotEmpty) ...[
                const Icon(Icons.schedule, size: 11, color: AppColors.warning),
                const SizedBox(width: 4),
                Text(
                  autoHint,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.warning,
                  ),
                ),
                const SizedBox(width: 10),
              ],
              const Expanded(
                child: Text(
                  'If wrong, see your manager.',
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.textMuted,
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

class _ReceivedRow extends StatelessWidget {
  final Map<String, dynamic> dist;
  const _ReceivedRow({required this.dist});

  @override
  Widget build(BuildContext context) {
    final sender = dist['sender_name']?.toString() ?? '—';
    final amt = double.tryParse(dist['amount']?.toString() ?? '0') ?? 0;
    final reason = dist['reason']?.toString();
    final date = dist['work_date']?.toString() ?? '';
    final isAuto = dist['status'] == 'auto_accepted';
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.south_west,
                size: 16, color: AppColors.success),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        'From $sender',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.text,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isAuto) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'AUTO',
                          style: TextStyle(
                            fontSize: 9,
                            color: AppColors.warning,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  date + (reason == null || reason.isEmpty ? '' : ' · $reason'),
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Text(
            '\$${amt.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppColors.success,
            ),
          ),
        ],
      ),
    );
  }
}


class _EntryRow extends StatelessWidget {
  final Map<String, dynamic> entry;
  final VoidCallback onTap;
  const _EntryRow({required this.entry, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final date = entry['date']?.toString() ?? '';
    final reported =
        double.tryParse(entry['reported_on_4070']?.toString() ?? '0') ?? 0;
    final shared =
        double.tryParse(entry['distributed_total']?.toString() ?? '0') ?? 0;
    final managerNote = entry['last_manager_note']?.toString();
    final managerName = entry['last_modified_by_name']?.toString();
    // 매니저 수정 표시 — source 가 manager 거나, 직원 외 actor 의 수정 audit 가 있음.
    final isManagerEdited =
        entry['source'] == 'manager' || (managerNote != null && managerNote.isNotEmpty);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                date.split('-').last,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.accent,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        date,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.text,
                        ),
                      ),
                      if (isManagerEdited) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppColors.warning.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Manager',
                            style: TextStyle(
                              fontSize: 9,
                              color: AppColors.warning,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (shared > 0)
                    Text(
                      'Shared out \$${shared.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                  // 가이드 §2.2.2 — 매니저 수정 내용을 직원이 볼 수 있게.
                  if (isManagerEdited && managerNote != null && managerNote.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      managerName != null && managerName.isNotEmpty
                          ? 'Modified by $managerName — $managerNote'
                          : 'Manager note: $managerNote',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.warning,
                        fontStyle: FontStyle.italic,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            Text(
              '\$${reported.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppColors.text,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorBanner({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: AppColors.danger, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 12, color: AppColors.danger),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
