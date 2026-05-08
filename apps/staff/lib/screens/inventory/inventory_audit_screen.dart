/// Inventory audit screen
///
/// Loads store inventory items locally on entry — no server call until submit.
/// Items sorted: Frequent section first, then All Items.
/// Section dividers shown only when both groups exist.
/// Each item: name, system qty, actual qty input (pre-filled with system qty), diff indicator.
/// "Show Modified Only" toggle: hides items where actual == system.
/// "Complete Audit" button: calls submitAudit API once to create audit+items+transactions.
/// On complete: show summary of changes.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:htm_core/htm_core.dart';
import '../../l10n/app_localizations.dart';
import '../../models/inventory.dart';
import '../../providers/inventory_provider.dart';
import '../../widgets/app_header.dart';

class InventoryAuditScreen extends ConsumerStatefulWidget {
  final String storeId;

  const InventoryAuditScreen({super.key, required this.storeId});

  @override
  ConsumerState<InventoryAuditScreen> createState() =>
      _InventoryAuditScreenState();
}

class _InventoryAuditScreenState
    extends ConsumerState<InventoryAuditScreen> {
  bool _showModifiedOnly = false;
  bool _isSubmitting = false;
  bool _completed = false;
  // Local copy of actual quantities keyed by StoreInventoryItem.id (= store_inventory_id)
  final Map<String, double> _actualQtys = {};

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      final state = ref.read(inventoryProvider);
      if (state.inventoryItems.isEmpty) {
        await ref.read(inventoryProvider.notifier).loadInventory(widget.storeId);
      }
      if (!mounted) return;
      // Pre-fill actual quantities with current system quantities
      for (final item in ref.read(inventoryProvider).inventoryItems) {
        _actualQtys[item.id] = item.currentQuantity.toDouble();
      }
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = AppL10n.of(context);
    final state = ref.watch(inventoryProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          AppHeader(
            title: t.auditHeader,
            isDetail: true,
            onBack: () => _onBack(context),
          ),
          if (state.isLoading && state.inventoryItems.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: AppColors.accent),
                    const SizedBox(height: 12),
                    Text(t.auditLoading,
                        style: const TextStyle(
                            fontSize: 14, color: AppColors.textSecondary)),
                  ],
                ),
              ),
            )
          else if (state.error != null && state.inventoryItems.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline,
                        size: 40, color: AppColors.textMuted),
                    const SizedBox(height: 10),
                    Text(state.error!,
                        style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary),
                        textAlign: TextAlign.center),
                    const SizedBox(height: 14),
                    ElevatedButton(
                      onPressed: () async {
                        await ref
                            .read(inventoryProvider.notifier)
                            .loadInventory(widget.storeId);
                        if (!mounted) return;
                        for (final item
                            in ref.read(inventoryProvider).inventoryItems) {
                          _actualQtys[item.id] =
                              item.currentQuantity.toDouble();
                        }
                        setState(() {});
                      },
                      child: Text(t.actionRetry),
                    ),
                  ],
                ),
              ),
            )
          else if (state.inventoryItems.isEmpty)
            Expanded(
              child: Center(
                child: Text(t.auditEmpty,
                    style: const TextStyle(
                        fontSize: 14, color: AppColors.textSecondary)),
              ),
            )
          else if (_completed)
            Expanded(child: _buildCompletedView())
          else
            Expanded(
                child: _buildAuditView(state.inventoryItems)),
        ],
      ),
    );
  }

  Widget _buildAuditView(List<StoreInventoryItem> allItems) {
    final frequentItems = allItems.where((i) => i.isFrequent).toList();
    final regularItems = allItems.where((i) => !i.isFrequent).toList();

    List<StoreInventoryItem> displayFrequent = frequentItems;
    List<StoreInventoryItem> displayRegular = regularItems;

    if (_showModifiedOnly) {
      displayFrequent = frequentItems
          .where((i) =>
              (_actualQtys[i.id] ?? i.currentQuantity.toDouble()) !=
              i.currentQuantity.toDouble())
          .toList();
      displayRegular = regularItems
          .where((i) =>
              (_actualQtys[i.id] ?? i.currentQuantity.toDouble()) !=
              i.currentQuantity.toDouble())
          .toList();
    }

    final hasBothSections = frequentItems.isNotEmpty && regularItems.isNotEmpty;

    return Column(
      children: [
        // Toolbar
        Container(
          color: AppColors.white,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Row(
            children: [
              Text(
                '${allItems.length} items',
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textSecondary),
              ),
              const Spacer(),
              // Modified-only toggle
              GestureDetector(
                onTap: () =>
                    setState(() => _showModifiedOnly = !_showModifiedOnly),
                child: Row(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 36,
                      height: 20,
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: _showModifiedOnly
                            ? AppColors.accent
                            : AppColors.border,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Align(
                        alignment: _showModifiedOnly
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.15),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      AppL10n.of(context).auditModifiedOnly,
                      style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        // Item list
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
            children: [
              if (hasBothSections && frequentItems.isNotEmpty) ...[
                _SectionHeader(label: AppL10n.of(context).auditSectionFrequent),
                const SizedBox(height: 8),
              ],
              ...displayFrequent.map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _AuditItemRow(
                      item: item,
                      actualQty: _actualQtys[item.id] ??
                          item.currentQuantity.toDouble(),
                      onChanged: (v) =>
                          setState(() => _actualQtys[item.id] = v),
                    ),
                  )),
              if (hasBothSections && regularItems.isNotEmpty) ...[
                const SizedBox(height: 8),
                _SectionHeader(label: AppL10n.of(context).auditSectionAll),
                const SizedBox(height: 8),
              ],
              ...displayRegular.map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _AuditItemRow(
                      item: item,
                      actualQty: _actualQtys[item.id] ??
                          item.currentQuantity.toDouble(),
                      onChanged: (v) =>
                          setState(() => _actualQtys[item.id] = v),
                    ),
                  )),
              if (displayFrequent.isEmpty && displayRegular.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      _showModifiedOnly
                          ? AppL10n.of(context).auditNoModified
                          : AppL10n.of(context).auditNoItems,
                      style: const TextStyle(
                          fontSize: 14, color: AppColors.textSecondary),
                    ),
                  ),
                ),
            ],
          ),
        ),
        // Complete button
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _completeAudit,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : Text(AppL10n.of(context).auditCompleteButton,
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700)),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCompletedView() {
    final items = ref.read(inventoryProvider).inventoryItems;
    // Items where actual qty differs from system qty
    final changed = items.where((item) {
      final actual = _actualQtys[item.id] ?? item.currentQuantity.toDouble();
      return actual != item.currentQuantity.toDouble();
    }).toList();

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Success banner
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.successBg,
            borderRadius: BorderRadius.circular(14),
            border:
                Border.all(color: AppColors.success.withValues(alpha: 0.3)),
          ),
          child: Column(
            children: [
              const Icon(Icons.check_circle_outline,
                  size: 40, color: AppColors.success),
              const SizedBox(height: 10),
              Text(
                AppL10n.of(context).auditCompleteHeading,
                style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text),
              ),
              const SizedBox(height: 6),
              Text(
                '${items.length} items audited · ${changed.length} adjustments',
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        if (changed.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text(
            AppL10n.of(context).auditAdjustmentsApplied,
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.text),
          ),
          const SizedBox(height: 10),
          ...changed.map((item) {
            final actual =
                _actualQtys[item.id] ?? item.currentQuantity.toDouble();
            final diff = actual - item.currentQuantity.toDouble();
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 6,
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      item.productName,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.text),
                    ),
                  ),
                  Text(
                    diff > 0
                        ? '+${diff.toStringAsFixed(0)}'
                        : diff.toStringAsFixed(0),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color:
                          diff > 0 ? AppColors.success : AppColors.danger,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => context.pop(),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(AppL10n.of(context).actionDone,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }

  Future<void> _completeAudit() async {
    final t = AppL10n.of(context);
    final confirmed = await AppModal.show(
      context,
      title: t.auditCompleteTitle,
      message: t.auditCompleteMessage,
      type: ModalType.confirm,
      confirmText: t.auditCompleteConfirm,
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isSubmitting = true);

    final items = _actualQtys.entries
        .map((e) => {
              'store_inventory_id': e.key,
              'actual_quantity': e.value.toInt(),
            })
        .toList();

    final ok = await ref
        .read(inventoryProvider.notifier)
        .submitAudit(widget.storeId, items);

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (ok) {
      setState(() => _completed = true);
      await AppModal.show(
        context,
        title: t.auditCompletedTitle,
        message: t.auditCompletedMessage,
        type: ModalType.success,
      );
    } else {
      await AppModal.show(
        context,
        title: t.commonSaveFailedTitle,
        message: t.auditFailedMessage,
        type: ModalType.error,
      );
    }
  }

  void _onBack(BuildContext context) {
    final t = AppL10n.of(context);
    if (_completed) {
      context.pop();
      return;
    }
    AppModal.show(
      context,
      title: t.auditExitTitle,
      message: t.auditExitMessage,
      type: ModalType.confirm,
      confirmText: t.actionExit,
    ).then((confirmed) {
      if (confirmed == true && mounted) {
        context.pop();
      }
    });
  }
}

// ─── Audit item row ────────────────────────────────────────────────────────

class _AuditItemRow extends StatefulWidget {
  final StoreInventoryItem item;
  final double actualQty;
  final void Function(double) onChanged;

  const _AuditItemRow({
    required this.item,
    required this.actualQty,
    required this.onChanged,
  });

  @override
  State<_AuditItemRow> createState() => _AuditItemRowState();
}

class _AuditItemRowState extends State<_AuditItemRow> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(
        text: widget.actualQty.toStringAsFixed(0));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String get _lastAuditedLabel {
    if (widget.item.lastAuditedAt == null) return 'Never';
    final diff = DateTime.now().difference(widget.item.lastAuditedAt!);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  String get _systemDisplay {
    final sys = widget.item.currentQuantity.toString();
    if (widget.item.subUnit != null && widget.item.subUnitRatio != null) {
      final subQty =
          widget.item.currentQuantity ~/ widget.item.subUnitRatio!;
      return '$sys ea ($subQty ${widget.item.subUnit}s)';
    }
    return '$sys ea';
  }

  double get _diff => widget.actualQty - widget.item.currentQuantity.toDouble();

  @override
  Widget build(BuildContext context) {
    final modified =
        widget.actualQty != widget.item.currentQuantity.toDouble();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: modified
            ? Border.all(color: AppColors.accent.withValues(alpha: 0.3))
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
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
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            widget.item.productName,
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.text),
                          ),
                        ),
                        if (widget.item.isFrequent) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFEBF5),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'Frequent',
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFFE84393)),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'System: $_systemDisplay · Last: $_lastAuditedLabel',
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
              // Difference indicator
              if (modified) ...[
                const SizedBox(width: 8),
                Text(
                  _diff > 0
                      ? '+${_diff.toStringAsFixed(0)}'
                      : _diff.toStringAsFixed(0),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _diff > 0 ? AppColors.success : AppColors.danger,
                  ),
                ),
              ] else ...[
                const SizedBox(width: 8),
                const Text(
                  '=',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textMuted),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          // Actual quantity input
          Row(
            children: [
              const Text(
                'Actual:',
                style: TextStyle(
                    fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 80,
                child: TextField(
                  controller: _ctrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    isDense: true,
                  ),
                  onChanged: (v) {
                    final parsed = double.tryParse(v);
                    if (parsed != null) widget.onChanged(parsed);
                  },
                ),
              ),
              const SizedBox(width: 6),
              const Text('ea',
                  style: TextStyle(
                      fontSize: 12, color: AppColors.textSecondary)),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Section header ───────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;

  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.accentBg,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            label,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.accent),
          ),
        ),
        const SizedBox(width: 8),
        const Expanded(child: Divider()),
      ],
    );
  }
}
