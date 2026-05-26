/// TipEntryDialog — Clock-out 직후 팁 입력.
///
/// mockup 결정 (2026-05-22):
///   - Card Tips / Cash Tips Kept ($ input)
///   - 분배 대상 picker (체크박스 + 이름/role + 금액 input)
///   - Split evenly 버튼
///   - 합계 표시 (over 시 빨간색)
///   - Skip / Submit Tips
///   - Submit 활성 조건: card/cash 두 input 다 채워짐 AND 분배 합 ≤ card_tips

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:htm_core/htm_core.dart';

import '../l10n/app_localizations.dart';
import '../models/tip_models.dart';
import '../utils/tip_entry_logic.dart';

class TipEntryDialog extends StatefulWidget {
  final String userName;
  final List<TipReceiver> receivers;
  final ValueChanged<TipPayload> onSubmit;
  final VoidCallback onSkip;
  /// 매장 전체 active 직원 — manual add 검색 풀 (L5). 빈 list 면 manual add UI 숨김.
  final List<TipReceiver> manualPool;

  const TipEntryDialog({
    super.key,
    required this.userName,
    required this.receivers,
    required this.onSubmit,
    required this.onSkip,
    this.manualPool = const [],
  });

  @override
  State<TipEntryDialog> createState() => _TipEntryDialogState();
}

class _TipEntryDialogState extends State<TipEntryDialog> {
  final _cardCtrl = TextEditingController();
  final _cashCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();
  final Set<String> _picked = {};
  final Map<String, TextEditingController> _amountCtrls = {};
  /// pool 에서 추가된 receivers — widget.receivers 와 합쳐 표시.
  final List<TipReceiver> _addedFromPool = [];
  bool _searchOpen = false;

  @override
  void dispose() {
    _cardCtrl.dispose();
    _cashCtrl.dispose();
    _searchCtrl.dispose();
    for (final c in _amountCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  /// 표시될 receivers — 자동 eligible + 사용자가 manual 추가한 사람.
  List<TipReceiver> get _allReceivers => [...widget.receivers, ..._addedFromPool];

  double get _cardTipsNum => parseAmount(_cardCtrl.text);

  double get _distSum =>
      computeDistSum(_picked.map((id) => _amountCtrls[id]?.text ?? ''));

  bool get _overDistributed => overDistributed(_distSum, _cardTipsNum);

  bool get _canSubmit => canSubmitTip(
        cardRaw: _cardCtrl.text,
        cashRaw: _cashCtrl.text,
        distSum: _distSum,
      );

  /// Pool 에서 직원 추가 — 자동 picked + amount controller 생성.
  void _addManualReceiver(TipReceiver r) {
    setState(() {
      _addedFromPool.add(r);
      _picked.add(r.userId);
      _amountCtrls[r.userId] = TextEditingController();
      _amountCtrls[r.userId]!.addListener(() => setState(() {}));
      _searchCtrl.clear();
    });
  }

  void _togglePick(String id) {
    setState(() {
      if (_picked.contains(id)) {
        _picked.remove(id);
        _amountCtrls.remove(id)?.dispose();
      } else {
        _picked.add(id);
        _amountCtrls[id] = TextEditingController();
        // 리스닝: amount 변경 시 합계 다시 그리도록
        _amountCtrls[id]!.addListener(() => setState(() {}));
      }
    });
  }

  void _splitEvenly() {
    final per = splitEvenlyAmount(_cardTipsNum, _picked.length);
    if (per == '0.00') return;
    setState(() {
      for (final id in _picked) {
        _amountCtrls[id]!.text = per;
      }
    });
  }

  void _submit() {
    if (!_canSubmit) return;
    final distributions = _picked
        .map((id) => TipDistribution(
              receiverId: id,
              amount: parseAmount(_amountCtrls[id]!.text),
            ))
        .toList();
    widget.onSubmit(TipPayload(
      cardTips: _cardTipsNum,
      cashTipsKept: parseAmount(_cashCtrl.text),
      distributions: distributions,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Material(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 800),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Header(userName: widget.userName),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: _MoneyField(label: AppL10n.of(context).pfTipCardLabel, sublabel: AppL10n.of(context).pfTipCardSub, controller: _cardCtrl, onChanged: () => setState(() {}))),
                      const SizedBox(width: 16),
                      Expanded(child: _MoneyField(label: AppL10n.of(context).pfTipCashLabel, sublabel: AppL10n.of(context).pfTipCashSub, controller: _cashCtrl, onChanged: () => setState(() {}))),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (widget.manualPool.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _ManualAddSection(
                      open: _searchOpen,
                      onToggle: () => setState(() => _searchOpen = !_searchOpen),
                      controller: _searchCtrl,
                      onChanged: (_) => setState(() {}),
                      pool: widget.manualPool,
                      alreadyAddedIds: _allReceivers.map((r) => r.userId).toSet(),
                      onPick: _addManualReceiver,
                    ),
                  ],
                  _DistributePanel(
                    receivers: _allReceivers,
                    picked: _picked,
                    amountCtrls: _amountCtrls,
                    cardTipsNum: _cardTipsNum,
                    distSum: _distSum,
                    overDistributed: _overDistributed,
                    onToggle: _togglePick,
                    onSplitEvenly: _splitEvenly,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 52,
                          child: OutlinedButton(
                            onPressed: widget.onSkip,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.textSecondary,
                              side: const BorderSide(color: AppColors.border, width: 2),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            child: Text(
                              AppL10n.of(context).pfTipSkip,
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SizedBox(
                          height: 52,
                          child: ElevatedButton(
                            onPressed: _canSubmit ? _submit : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.accent,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: AppColors.accent.withValues(alpha: 0.4),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            child: Text(
                              AppL10n.of(context).pfTipSubmit,
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
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

class _Header extends StatelessWidget {
  final String userName;
  const _Header({required this.userName});

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t.pfTipHeader,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: AppColors.accent,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          t.pfTipTitle(userName),
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.text),
        ),
        const SizedBox(height: 4),
        Text(
          t.pfTipBody,
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

class _MoneyField extends StatelessWidget {
  final String label;
  final String sublabel;
  final TextEditingController controller;
  final VoidCallback onChanged;
  const _MoneyField({
    required this.label,
    required this.sublabel,
    required this.controller,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.text)),
        const SizedBox(height: 2),
        Text(sublabel, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          onChanged: (_) => onChanged(),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
          decoration: InputDecoration(
            prefixText: '\$ ',
            prefixStyle: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.textSecondary,
            ),
            hintText: '0.00',
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: AppColors.border, width: 2),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: AppColors.border, width: 2),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: AppColors.accent, width: 2),
            ),
          ),
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.text),
        ),
      ],
    );
  }
}

class _DistributePanel extends StatelessWidget {
  final List<TipReceiver> receivers;
  final Set<String> picked;
  final Map<String, TextEditingController> amountCtrls;
  final double cardTipsNum;
  final double distSum;
  final bool overDistributed;
  final ValueChanged<String> onToggle;
  final VoidCallback onSplitEvenly;

  const _DistributePanel({
    required this.receivers,
    required this.picked,
    required this.amountCtrls,
    required this.cardTipsNum,
    required this.distSum,
    required this.overDistributed,
    required this.onToggle,
    required this.onSplitEvenly,
  });

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);
    final showSplit = picked.isNotEmpty && cardTipsNum > 0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border.all(color: AppColors.border, width: 2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.pfTipDistributeHeader,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textSecondary,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      t.pfTipDistributeSub,
                      style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
              if (showSplit)
                TextButton(
                  onPressed: onSplitEvenly,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.accent,
                    backgroundColor: AppColors.accentBg,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text(
                    t.pfTipSplitEvenly,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (receivers.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  t.pfTipNoTeammates,
                  style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                ),
              ),
            )
          else
            ...receivers.map((r) => _ReceiverRow(
                  receiver: r,
                  selected: picked.contains(r.userId),
                  amountController: amountCtrls[r.userId],
                  onToggle: () => onToggle(r.userId),
                )),
          if (picked.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: overDistributed
                    ? AppColors.dangerBg
                    : AppColors.bg.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      t.pfTipDistributedLine(
                        distSum.toStringAsFixed(2),
                        cardTipsNum.toStringAsFixed(2),
                      ),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: overDistributed ? AppColors.danger : AppColors.textSecondary,
                      ),
                    ),
                  ),
                  if (overDistributed)
                    Text(
                      t.pfTipOverBy((distSum - cardTipsNum).toStringAsFixed(2)),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppColors.danger,
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
}

class _ReceiverRow extends StatelessWidget {
  final TipReceiver receiver;
  final bool selected;
  final TextEditingController? amountController;
  final VoidCallback onToggle;

  const _ReceiverRow({
    required this.receiver,
    required this.selected,
    required this.amountController,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppColors.accentBg.withValues(alpha: 0.5) : AppColors.white,
            border: Border.all(
              color: selected ? AppColors.accent : AppColors.border,
              width: 2,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: selected ? AppColors.accent : AppColors.white,
                  border: Border.all(
                    color: selected ? AppColors.accent : AppColors.textMuted,
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
                alignment: Alignment.center,
                child: selected
                    ? const Icon(Icons.check, size: 14, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      receiver.userName,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.text),
                    ),
                    Text(
                      [
                        if ((receiver.role ?? '').isNotEmpty) receiver.role,
                        AppL10n.of(context).pfTipWorked(receiver.workedHours.toString()),
                      ].whereType<String>().join(' · '),
                      style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
              if (selected && amountController != null)
                SizedBox(
                  width: 110,
                  child: TextField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
                    textAlign: TextAlign.right,
                    decoration: InputDecoration(
                      prefixText: '\$ ',
                      hintText: '0.00',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppColors.border, width: 2),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppColors.border, width: 2),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppColors.accent, width: 2),
                      ),
                    ),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.text),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ManualAddSection extends StatelessWidget {
  final bool open;
  final VoidCallback onToggle;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final List<TipReceiver> pool;
  final Set<String> alreadyAddedIds;
  final ValueChanged<TipReceiver> onPick;

  const _ManualAddSection({
    required this.open,
    required this.onToggle,
    required this.controller,
    required this.onChanged,
    required this.pool,
    required this.alreadyAddedIds,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final q = controller.text.trim().toLowerCase();
    final candidates = pool
        .where((r) => !alreadyAddedIds.contains(r.userId))
        .where((r) => q.isEmpty || r.userName.toLowerCase().contains(q))
        .take(8) // 화면 부담 — 8개로 cap
        .toList();

    if (!open) {
      return Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: onToggle,
          icon: const Icon(Icons.add_circle_outline, size: 18, color: AppColors.accent),
          label: Text(
            AppL10n.of(context).pfTipAddTeammateButton,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.accent),
          ),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.accentBg.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.4), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  AppL10n.of(context).pfTipAddTeammateHeader,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppColors.accent,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              IconButton(
                onPressed: onToggle,
                icon: const Icon(Icons.close, size: 18, color: AppColors.textSecondary),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 4),
          TextField(
            controller: controller,
            onChanged: onChanged,
            autofocus: true,
            decoration: InputDecoration(
              hintText: AppL10n.of(context).pfTipAddSearchHint,
              prefixIcon: const Icon(Icons.search, size: 18, color: AppColors.textMuted),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.border, width: 1.5),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.border, width: 1.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.accent, width: 2),
              ),
            ),
            style: const TextStyle(fontSize: 14, color: AppColors.text),
          ),
          const SizedBox(height: 8),
          if (candidates.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(
                AppL10n.of(context).pfTipAddNoMatch,
                style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
            )
          else
            ...candidates.map((r) => InkWell(
                  onTap: () => onPick(r),
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.person_add_alt, size: 16, color: AppColors.accent),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            r.userName,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.text,
                            ),
                          ),
                        ),
                        if ((r.role ?? '').isNotEmpty)
                          Text(
                            r.role!,
                            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                          ),
                      ],
                    ),
                  ),
                )),
        ],
      ),
    );
  }
}
