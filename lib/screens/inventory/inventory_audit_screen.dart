/// Inventory audit screen
///
/// Starts a new audit for the store on entry.
/// Items sorted: Frequent section first, then All Items.
/// Section dividers shown only when both groups exist.
/// Each item: name, system qty, actual qty input (pre-filled with system qty), diff indicator.
/// "Show Modified Only" toggle: hides items where actual == system.
/// "Complete Audit" button always enabled (all items pre-filled).
/// On complete: show summary of changes.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../config/theme.dart';
import '../../models/inventory.dart';
import '../../providers/inventory_provider.dart';
import '../../services/inventory_service.dart';
import '../../widgets/app_header.dart';
import '../../widgets/app_modal.dart';
import '../../utils/toast_manager.dart';

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
  bool _isStarting = true;
  bool _completed = false;
  // Local copy of actual quantities keyed by audit item id
  final Map<String, double> _actualQtys = {};

  @override
  void initState() {
    super.initState();
    Future.microtask(_startAudit);
  }

  Future<void> _startAudit() async {
    final audit = await ref
        .read(inventoryProvider.notifier)
        .startAudit(widget.storeId);
    if (!mounted) return;
    if (audit != null) {
      for (final item in audit.items) {
        _actualQtys[item.id] = item.systemQuantity;
      }
    }
    setState(() => _isStarting = false);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(inventoryProvider);
    final audit = state.currentAudit;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          AppHeader(
            title: 'Audit',
            isDetail: true,
            onBack: () => _onBack(context),
          ),
          if (_isStarting)
            const Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: AppColors.accent),
                    SizedBox(height: 12),
                    Text('Starting audit...',
                        style: TextStyle(
                            fontSize: 14, color: AppColors.textSecondary)),
                  ],
                ),
              ),
            )
          else if (state.error != null)
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
                      onPressed: () {
                        setState(() => _isStarting = true);
                        _startAudit();
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
          else if (audit == null)
            const Expanded(
              child: Center(
                child: Text('No audit data',
                    style: TextStyle(
                        fontSize: 14, color: AppColors.textSecondary)),
              ),
            )
          else if (_completed)
            Expanded(child: _buildCompletedView(audit))
          else
            Expanded(child: _buildAuditView(audit, state.isLoading)),
        ],
      ),
    );
  }

  Widget _buildAuditView(InventoryAudit audit, bool isLoading) {
    final allItems = audit.items;
    final frequentItems = allItems.where((i) => i.isFrequent).toList();
    final regularItems = allItems.where((i) => !i.isFrequent).toList();

    List<InventoryAuditItem> displayFrequent = frequentItems;
    List<InventoryAuditItem> displayRegular = regularItems;

    if (_showModifiedOnly) {
      displayFrequent = frequentItems
          .where((i) => (_actualQtys[i.id] ?? i.systemQuantity) != i.systemQuantity)
          .toList();
      displayRegular = regularItems
          .where((i) => (_actualQtys[i.id] ?? i.systemQuantity) != i.systemQuantity)
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
              // Progress
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
                    const Text(
                      'Modified only',
                      style: TextStyle(
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
                _SectionHeader(label: 'Frequent'),
                const SizedBox(height: 8),
              ],
              ...displayFrequent.map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _AuditItemRow(
                      item: item,
                      actualQty: _actualQtys[item.id] ?? item.systemQuantity,
                      onChanged: (v) => setState(() => _actualQtys[item.id] = v),
                    ),
                  )),
              if (hasBothSections && regularItems.isNotEmpty) ...[
                const SizedBox(height: 8),
                _SectionHeader(label: 'All Items'),
                const SizedBox(height: 8),
              ],
              ...displayRegular.map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _AuditItemRow(
                      item: item,
                      actualQty: _actualQtys[item.id] ?? item.systemQuantity,
                      onChanged: (v) => setState(() => _actualQtys[item.id] = v),
                    ),
                  )),
              if (displayFrequent.isEmpty && displayRegular.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      _showModifiedOnly
                          ? 'No modified items yet'
                          : 'No items in audit',
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
                onPressed: isLoading ? null : () => _completeAudit(audit),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Text('Complete Audit',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700)),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCompletedView(InventoryAudit audit) {
    final changed = audit.items
        .where((i) => i.difference != 0)
        .toList();

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
              const Text(
                'Audit Complete',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text),
              ),
              const SizedBox(height: 6),
              Text(
                '${audit.items.length} items audited · ${changed.length} adjustments',
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        if (changed.isNotEmpty) ...[
          const SizedBox(height: 20),
          const Text(
            'Adjustments Applied',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.text),
          ),
          const SizedBox(height: 10),
          ...changed.map((item) => Container(
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
                      item.difference > 0
                          ? '+${item.difference.toStringAsFixed(0)}'
                          : item.difference.toStringAsFixed(0),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: item.difference > 0
                            ? AppColors.success
                            : AppColors.danger,
                      ),
                    ),
                  ],
                ),
              )),
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
            child: const Text('Done',
                style:
                    TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }

  Future<void> _completeAudit(InventoryAudit audit) async {
    final confirmed = await AppModal.show(
      context,
      title: 'Complete Audit',
      message:
          'This will apply all quantity adjustments. Are you sure?',
      type: ModalType.confirm,
      confirmText: 'Complete',
    );
    if (confirmed != true || !mounted) return;

    // Save actual quantities before completing
    final items = _actualQtys.entries
        .map((e) => {'id': e.key, 'actual_quantity': e.value})
        .toList();
    await ref.read(inventoryServiceProvider).updateAuditItems(
          widget.storeId, audit.id, items);

    final ok = await ref
        .read(inventoryProvider.notifier)
        .completeAudit(widget.storeId, audit.id);

    if (!mounted) return;
    if (ok) {
      setState(() => _completed = true);
    } else {
      ToastManager().error(context, 'Failed to complete audit.');
    }
  }

  void _onBack(BuildContext context) {
    if (_completed) {
      context.pop();
      return;
    }
    AppModal.show(
      context,
      title: 'Exit Audit',
      message:
          'Are you sure? Progress will not be saved.',
      type: ModalType.confirm,
      confirmText: 'Exit',
    ).then((confirmed) {
      if (confirmed == true && mounted) {
        ref.read(inventoryProvider.notifier).clearAudit();
        context.pop();
      }
    });
  }
}

// ─── Audit item row ────────────────────────────────────────────────────────

class _AuditItemRow extends StatefulWidget {
  final InventoryAuditItem item;
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
    final sys = widget.item.systemQuantity.toStringAsFixed(0);
    if (widget.item.subUnit != null && widget.item.subUnitRatio != null) {
      final subQty =
          widget.item.systemQuantity ~/ widget.item.subUnitRatio!;
      return '$sys ea ($subQty ${widget.item.subUnit}s)';
    }
    return '$sys ea';
  }

  double get _diff => widget.actualQty - widget.item.systemQuantity;

  @override
  Widget build(BuildContext context) {
    final modified = widget.actualQty != widget.item.systemQuantity;

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
