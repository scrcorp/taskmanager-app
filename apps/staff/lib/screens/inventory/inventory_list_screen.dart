/// Inventory list screen — view and manage store stock
///
/// Search bar + status filter chips (All / Low Stock / Frequent Only)
/// Product cards sorted: frequent first, then oldest audited.
/// Tap card → bottom sheet with stock in/out/adjust buttons.
/// Stock In/Out/Adjust → center dialog on top of sheet.
/// FAB "+" → add product screen (SV+ only).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../config/theme.dart';
import '../../models/inventory.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/app_header.dart';
import '../../widgets/app_modal.dart';

class InventoryListScreen extends ConsumerStatefulWidget {
  final String storeId;
  /// Optional pre-applied status filter (e.g. 'low' from home screen banner)
  final String? initialStatus;

  const InventoryListScreen({
    super.key,
    required this.storeId,
    this.initialStatus,
  });

  @override
  ConsumerState<InventoryListScreen> createState() =>
      _InventoryListScreenState();
}

class _InventoryListScreenState
    extends ConsumerState<InventoryListScreen> {
  final _searchCtrl = TextEditingController();
  String _statusFilter = 'all'; // 'all' | 'low' | 'frequent'

  @override
  void initState() {
    super.initState();
    if (widget.initialStatus != null) {
      _statusFilter = widget.initialStatus!;
    }
    Future.microtask(() => _loadInventory());
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _loadInventory() {
    ref.read(inventoryProvider.notifier).loadInventory(
          widget.storeId,
          keyword: _searchCtrl.text.trim().isEmpty
              ? null
              : _searchCtrl.text.trim(),
          status: _statusFilter == 'low' ? 'low' : null,
          isFrequent: _statusFilter == 'frequent' ? true : null,
        );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(inventoryProvider);
    final user = ref.watch(authProvider).user;
    final canManage = user != null && user.hasPermission('inventory:create');
    final canDelete = user != null && user.hasPermission('inventory:delete');

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          AppHeader(
            title: 'View Inventory',
            isDetail: true,
            onBack: () => context.pop(),
          ),
          // Search + filters
          Container(
            color: AppColors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              children: [
                // Search bar
                TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Search products...',
                    prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.textMuted),
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? GestureDetector(
                            onTap: () {
                              _searchCtrl.clear();
                              _loadInventory();
                              setState(() {});
                            },
                            child: const Icon(Icons.close, size: 18, color: AppColors.textMuted),
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                  ),
                  onChanged: (_) {
                    setState(() {});
                    _loadInventory();
                  },
                ),
                const SizedBox(height: 10),
                // Filter chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _FilterChip(
                        label: 'All',
                        selected: _statusFilter == 'all',
                        onTap: () => _setFilter('all'),
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'Low Stock',
                        selected: _statusFilter == 'low',
                        onTap: () => _setFilter('low'),
                        selectedColor: AppColors.warning,
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'Frequent Only',
                        selected: _statusFilter == 'frequent',
                        onTap: () => _setFilter('frequent'),
                        selectedColor: const Color(0xFFE84393),
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
            child: _buildList(state, canManage),
          ),
        ],
      ),
      floatingActionButton: canManage
          ? FloatingActionButton(
              onPressed: () =>
                  context.push('/inventory/${widget.storeId}/add-product'),
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  void _setFilter(String filter) {
    if (_statusFilter == filter) {
      setState(() => _statusFilter = 'all');
    } else {
      setState(() => _statusFilter = filter);
    }
    _loadInventory();
  }

  Widget _buildList(InventoryState state, bool canManage) {
    if (state.isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.accent));
    }

    if (state.error != null && state.inventoryItems.isEmpty) {
      // Only show full-screen error if no data at all
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 40, color: AppColors.textMuted),
            const SizedBox(height: 10),
            Text(
              state.error!,
              style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            ElevatedButton(
              onPressed: _loadInventory,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (state.inventoryItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.inventory_2_outlined,
                size: 48, color: AppColors.textMuted),
            const SizedBox(height: 12),
            Text(
              _statusFilter == 'all'
                  ? 'No products in inventory'
                  : 'No matching products',
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.text),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.accent,
      onRefresh: () async => _loadInventory(),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        itemCount: state.inventoryItems.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final item = state.inventoryItems[index];
          return _ProductCard(
            item: item,
            onTap: () => _showDetailSheet(item, canManage),
          );
        },
      ),
    );
  }

  void _showDetailSheet(StoreInventoryItem item, bool canManage) {
    ref.read(inventoryProvider.notifier).selectItem(item);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ProductDetailSheet(
        item: item,
        storeId: widget.storeId,
        canManage: canManage,
        onStockIn: () => _showStockDialog(item, 'in'),
        onStockOut: () => _showStockDialog(item, 'out'),
        onAdjust: () => _showAdjustDialog(item),
      ),
    );
  }

  void _showStockDialog(StoreInventoryItem item, String type) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _StockDialog(
        item: item,
        type: type,
        onConfirm: (qty, reason) async {
          Navigator.of(ctx).pop();
          bool ok;
          if (type == 'in') {
            ok = await ref.read(inventoryProvider.notifier).stockIn(
                  widget.storeId,
                  item.id,
                  qty,
                  reason,
                );
          } else {
            ok = await ref.read(inventoryProvider.notifier).stockOut(
                  widget.storeId,
                  item.id,
                  qty,
                  reason,
                );
          }
          if (!mounted) return;
          if (ok) {
            final label = type == 'in' ? 'Stock in recorded' : 'Stock out recorded';
            await AppModal.show(
              context,
              title: 'Saved',
              message: label,
              type: ModalType.success,
            );
            if (!mounted) return;
            await ref.read(inventoryProvider.notifier).loadSummary(widget.storeId);
            // Close bottom sheet and reopen with updated data
            if (mounted) {
              Navigator.of(context).pop(); // close bottom sheet
              final updated = ref.read(inventoryProvider).inventoryItems
                  .where((i) => i.id == item.id).firstOrNull;
              final user = ref.read(authProvider).user;
              final manage = user != null && user.hasPermission('inventory:create');
              if (updated != null) _showDetailSheet(updated, manage);
            }
          } else {
            await AppModal.show(
              context,
              title: "Couldn't save",
              message: 'Failed to record. Please try again.',
              type: ModalType.error,
            );
          }
        },
      ),
    );
  }

  void _showAdjustDialog(StoreInventoryItem item) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _AdjustDialog(
        item: item,
        onConfirm: (qty, reason) async {
          Navigator.of(ctx).pop();
          final ok = await ref.read(inventoryProvider.notifier).adjustStock(
                widget.storeId,
                item.id,
                qty,
                reason,
              );
          if (!mounted) return;
          if (ok) {
            await AppModal.show(
              context,
              title: 'Adjusted',
              message: 'Quantity adjusted',
              type: ModalType.success,
            );
            if (!mounted) return;
            await ref.read(inventoryProvider.notifier).loadSummary(widget.storeId);
            // Close bottom sheet and reopen with updated data
            if (mounted) {
              Navigator.of(context).pop(); // close bottom sheet
              final updated = ref.read(inventoryProvider).inventoryItems
                  .where((i) => i.id == item.id).firstOrNull;
              final user = ref.read(authProvider).user;
              final manage = user != null && user.hasPermission('inventory:create');
              if (updated != null) _showDetailSheet(updated, manage);
            }
          } else {
            await AppModal.show(
              context,
              title: "Couldn't adjust",
              message: 'Failed to adjust. Please try again.',
              type: ModalType.error,
            );
          }
        },
      ),
    );
  }
}

// ─── Filter chip ────────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? selectedColor;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.selectedColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = selectedColor ?? AppColors.accent;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.12) : AppColors.bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? color : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? color : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

// ─── Product card ────────────────────────────────────────────────────────────

class _ProductCard extends StatelessWidget {
  final StoreInventoryItem item;
  final VoidCallback onTap;

  const _ProductCard({required this.item, required this.onTap});

  Color get _statusColor {
    switch (item.status) {
      case kStatusLow:
        return AppColors.warning;
      case kStatusOut:
        return AppColors.danger;
      default:
        return AppColors.success;
    }
  }

  String get _statusLabel {
    switch (item.status) {
      case kStatusLow:
        return 'Low';
      case kStatusOut:
        return 'Out';
      default:
        return 'OK';
    }
  }

  String get _lastAuditedLabel {
    if (item.lastAuditedAt == null) return 'Never audited';
    final diff = DateTime.now().difference(item.lastAuditedAt!);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
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
        child: Row(
          children: [
            // Thumbnail
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.bg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: item.imageUrl != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(
                        item.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.inventory_2_outlined,
                          size: 24,
                          color: AppColors.textMuted,
                        ),
                      ),
                    )
                  : const Icon(Icons.inventory_2_outlined,
                      size: 24, color: AppColors.textMuted),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name + badges
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.productName,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.text,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (item.isFrequent) ...[
                        const SizedBox(width: 6),
                        _Badge(label: 'Frequent', color: const Color(0xFFE84393)),
                      ],
                    ],
                  ),
                  if (item.description != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      item.description!,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      // Quantity
                      Text(
                        item.quantityDisplay,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _statusColor,
                        ),
                      ),
                      const Spacer(),
                      // Status badge
                      _Badge(label: _statusLabel, color: _statusColor),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Last: $_lastAuditedLabel',
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;

  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label,
        style: TextStyle(
            fontSize: 10, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}

// ─── Product detail bottom sheet ────────────────────────────────────────────

class _ProductDetailSheet extends StatelessWidget {
  final StoreInventoryItem item;
  final String storeId;
  final bool canManage;
  final VoidCallback onStockIn;
  final VoidCallback onStockOut;
  final VoidCallback onAdjust;

  const _ProductDetailSheet({
    required this.item,
    required this.storeId,
    required this.canManage,
    required this.onStockIn,
    required this.onStockOut,
    required this.onAdjust,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 16),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Product header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.bg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: item.imageUrl != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(item.imageUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(
                                  Icons.inventory_2_outlined,
                                  size: 28,
                                  color: AppColors.textMuted)),
                        )
                      : const Icon(Icons.inventory_2_outlined,
                          size: 28, color: AppColors.textMuted),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.productName,
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.text),
                      ),
                      if (item.productCode != null)
                        Text(item.productCode!,
                            style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textMuted)),
                      if (item.description != null)
                        Text(
                          item.description!,
                          style: const TextStyle(
                              fontSize: 13, color: AppColors.textSecondary),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Quantity row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Current Stock',
                        style: TextStyle(
                            fontSize: 12, color: AppColors.textMuted)),
                    const SizedBox(height: 2),
                    Text(
                      item.quantityDisplay,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: item.status == kStatusOut
                            ? AppColors.danger
                            : item.status == kStatusLow
                                ? AppColors.warning
                                : AppColors.success,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                if (item.isFrequent)
                  _Badge(label: 'Frequent', color: const Color(0xFFE84393)),
                const SizedBox(width: 6),
                _Badge(
                  label: item.status == kStatusOut
                      ? 'Out of Stock'
                      : item.status == kStatusLow
                          ? 'Low Stock'
                          : 'In Stock',
                  color: item.status == kStatusOut
                      ? AppColors.danger
                      : item.status == kStatusLow
                          ? AppColors.warning
                          : AppColors.success,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Divider(height: 1),
          const SizedBox(height: 16),
          // Action buttons (SV+ only)
          if (canManage)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: _ActionButton(
                      label: 'Stock In',
                      icon: Icons.add,
                      color: AppColors.success,
                      onTap: () {
                        onStockIn();
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _ActionButton(
                      label: 'Stock Out',
                      icon: Icons.remove,
                      color: AppColors.warning,
                      onTap: () {
                        onStockOut();
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _ActionButton(
                      label: 'Adjust',
                      icon: Icons.tune,
                      color: AppColors.accent,
                      onTap: () {
                        onAdjust();
                      },
                    ),
                  ),
                ],
              ),
            ),
          if (!canManage)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Only SV and above can perform stock operations.',
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700, color: color),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Stock In / Out dialog ────────────────────────────────────────────────────

class _StockDialog extends StatefulWidget {
  final StoreInventoryItem item;
  /// 'in' or 'out'
  final String type;
  final void Function(int quantity, String? reason) onConfirm;

  const _StockDialog({
    required this.item,
    required this.type,
    required this.onConfirm,
  });

  @override
  State<_StockDialog> createState() => _StockDialogState();
}

class _StockDialogState extends State<_StockDialog> {
  int _qty = 1;
  bool _useSubUnit = false;
  final _reasonCtrl = TextEditingController();
  late final TextEditingController _qtyCtrl;

  @override
  void initState() {
    super.initState();
    _qtyCtrl = TextEditingController(text: '1');
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _reasonCtrl.dispose();
    super.dispose();
  }

  bool get _hasSubUnit =>
      widget.item.subUnit != null && widget.item.subUnitRatio != null;

  int get _eaQuantity =>
      _useSubUnit ? _qty * (widget.item.subUnitRatio ?? 1) : _qty;

  bool get _willBeNegative =>
      widget.type == 'out' &&
      widget.item.currentQuantity - _eaQuantity < 0;

  @override
  Widget build(BuildContext context) {
    final isStockIn = widget.type == 'in';
    final color = isStockIn ? AppColors.success : AppColors.warning;
    final title = isStockIn ? 'Stock In' : 'Stock Out';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text)),
            const SizedBox(height: 4),
            Text(widget.item.productName,
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            // Quantity control
            Row(
              children: [
                // Sub-unit toggle
                if (_hasSubUnit)
                  GestureDetector(
                    onTap: () =>
                        setState(() => _useSubUnit = !_useSubUnit),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: _useSubUnit
                            ? AppColors.accentBg
                            : AppColors.bg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _useSubUnit
                              ? AppColors.accent
                              : AppColors.border,
                        ),
                      ),
                      child: Text(
                        _useSubUnit
                            ? widget.item.subUnit!
                            : 'ea',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _useSubUnit
                              ? AppColors.accent
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                if (_hasSubUnit) const SizedBox(width: 10),
                // - qty + row
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _QtyButton(
                        icon: Icons.remove,
                        onTap: _qty > 1
                            ? () => setState(() {
                                  _qty--;
                                  _qtyCtrl.text = '$_qty';
                                })
                            : null,
                      ),
                      SizedBox(
                        width: 80,
                        child: TextField(
                          controller: _qtyCtrl,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: AppColors.text),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            isDense: true,
                          ),
                          onChanged: (v) {
                            final parsed = int.tryParse(v);
                            if (parsed != null && parsed > 0) {
                              setState(() => _qty = parsed);
                            }
                          },
                        ),
                      ),
                      _QtyButton(
                        icon: Icons.add,
                        onTap: () => setState(() {
                          _qty++;
                          _qtyCtrl.text = '$_qty';
                        }),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            // Conversion preview for sub-unit
            if (_hasSubUnit && _useSubUnit) ...[
              const SizedBox(height: 6),
              Text(
                '= $_eaQuantity ea',
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
            // Negative warning
            if (_willBeNegative) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.warningBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Will result in negative stock '
                  '(${widget.item.currentQuantity - _eaQuantity} ea)',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.warning),
                ),
              ),
            ],
            const SizedBox(height: 14),
            // Reason field
            TextField(
              controller: _reasonCtrl,
              decoration: const InputDecoration(
                hintText: 'Reason (optional)',
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 20),
            // Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      side: const BorderSide(color: AppColors.border),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      padding:
                          const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => widget.onConfirm(
                      _eaQuantity,
                      _reasonCtrl.text.trim().isEmpty
                          ? null
                          : _reasonCtrl.text.trim(),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      padding:
                          const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(title),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Adjust dialog ───────────────────────────────────────────────────────────

class _AdjustDialog extends StatefulWidget {
  final StoreInventoryItem item;
  final void Function(int quantity, String? reason) onConfirm;

  const _AdjustDialog({required this.item, required this.onConfirm});

  @override
  State<_AdjustDialog> createState() => _AdjustDialogState();
}

class _AdjustDialogState extends State<_AdjustDialog> {
  late final TextEditingController _qtyCtrl;
  final _reasonCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _qtyCtrl = TextEditingController(
        text: '${widget.item.currentQuantity}');
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _reasonCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Adjust Quantity',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text)),
            const SizedBox(height: 4),
            Text(widget.item.productName,
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            Text(
              'Set new quantity (current: ${widget.item.currentQuantity} ea)',
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _qtyCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'New quantity (ea)',
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _reasonCtrl,
              decoration: const InputDecoration(
                hintText: 'Reason (optional)',
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      side: const BorderSide(color: AppColors.border),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      padding:
                          const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      final qty = int.tryParse(_qtyCtrl.text.trim()) ?? 0;
                      widget.onConfirm(
                        qty,
                        _reasonCtrl.text.trim().isEmpty
                            ? null
                            : _reasonCtrl.text.trim(),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      padding:
                          const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Adjust'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Qty button helper ────────────────────────────────────────────────────────

class _QtyButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _QtyButton({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: onTap != null ? AppColors.accentBg : AppColors.bg,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          size: 18,
          color: onTap != null ? AppColors.accent : AppColors.textMuted,
        ),
      ),
    );
  }
}
