/// Stock In screen — multi-item bulk stock in
///
/// Header: date (today, tappable) + person (logged-in user, read-only)
/// Items list: empty state → "Tap + to add items"
/// "+" button → product search bottom sheet → tap to add item
/// Each item: thumbnail, name, qty input (+/-), unit toggle, remove
/// Sub-unit toggle: if product has sub_unit, show conversion preview
/// Reason textarea (shared, optional)
/// Save button: enabled only when items list is non-empty
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../config/theme.dart';
import '../../models/inventory.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/inventory_service.dart';
import '../../widgets/app_header.dart';
import '../../utils/toast_manager.dart';

/// Mutable line item for the stock-in form
class _LineItem {
  final StoreInventoryItem inventoryItem;
  int quantity;
  bool useSubUnit;

  _LineItem({
    required this.inventoryItem,
    this.quantity = 1,
    this.useSubUnit = false,
  });

  int get eaQuantity =>
      useSubUnit && inventoryItem.subUnit != null && inventoryItem.subUnitRatio != null
          ? quantity * inventoryItem.subUnitRatio!
          : quantity;

  bool get hasSubUnit =>
      inventoryItem.subUnit != null && inventoryItem.subUnitRatio != null;
}

class StockInScreen extends ConsumerStatefulWidget {
  final String storeId;

  const StockInScreen({super.key, required this.storeId});

  @override
  ConsumerState<StockInScreen> createState() => _StockInScreenState();
}

class _StockInScreenState extends ConsumerState<StockInScreen> {
  DateTime _date = DateTime.now();
  final List<_LineItem> _items = [];
  final _reasonCtrl = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _reasonCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final userName = user?.fullName ?? '-';

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          AppHeader(
            title: 'Stock In',
            isDetail: true,
            onBack: () => context.pop(),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // Header info card
                _buildHeaderCard(userName),
                const SizedBox(height: 16),
                // Items section
                _buildItemsSection(),
                const SizedBox(height: 16),
                // Reason
                _buildReasonField(),
                const SizedBox(height: 24),
                // Save button
                _buildSaveButton(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCard(String userName) {
    return Container(
      padding: const EdgeInsets.all(16),
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
          // Date field
          GestureDetector(
            onTap: _pickDate,
            child: Row(
              children: [
                const Icon(Icons.calendar_today_outlined,
                    size: 18, color: AppColors.accent),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    DateFormat('EEEE, MMMM d, yyyy').format(_date),
                    style: const TextStyle(
                        fontSize: 14, color: AppColors.text),
                  ),
                ),
                const Icon(Icons.chevron_right,
                    size: 18, color: AppColors.textMuted),
              ],
            ),
          ),
          const Divider(height: 20),
          // Person field
          Row(
            children: [
              const Icon(Icons.person_outline,
                  size: 18, color: AppColors.textMuted),
              const SizedBox(width: 10),
              Text(
                userName,
                style: const TextStyle(
                    fontSize: 14, color: AppColors.textSecondary),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.bg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'You',
                  style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildItemsSection() {
    return Container(
      padding: const EdgeInsets.all(16),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Items',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.text),
              ),
              const Spacer(),
              GestureDetector(
                onTap: _showProductSearch,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.accentBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.add, size: 20, color: AppColors.accent),
                ),
              ),
            ],
          ),
          if (_items.isEmpty) ...[
            const SizedBox(height: 24),
            Center(
              child: Column(
                children: const [
                  Icon(Icons.add_shopping_cart_outlined,
                      size: 40, color: AppColors.textMuted),
                  SizedBox(height: 8),
                  Text(
                    'Tap + to add items',
                    style: TextStyle(
                        fontSize: 14, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ] else ...[
            const SizedBox(height: 12),
            ...List.generate(_items.length, (i) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _ItemRow(
                  lineItem: _items[i],
                  onQtyChanged: (qty) => setState(() => _items[i].quantity = qty),
                  onUnitToggle: () =>
                      setState(() => _items[i].useSubUnit = !_items[i].useSubUnit),
                  onRemove: () => setState(() => _items.removeAt(i)),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildReasonField() {
    return Container(
      padding: const EdgeInsets.all(16),
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
      child: TextField(
        controller: _reasonCtrl,
        maxLines: 3,
        decoration: const InputDecoration(
          labelText: 'Reason (optional)',
          hintText: 'e.g. Weekly delivery from supplier',
          border: OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    final enabled = _items.isNotEmpty && !_isSaving;
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: enabled ? _save : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: enabled ? AppColors.success : AppColors.textMuted,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.border,
          disabledForegroundColor: AppColors.textMuted,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: _isSaving
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2))
            : const Text('Save',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700)),
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _date = picked);
  }

  void _showProductSearch() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ProductSearchSheet(
        storeId: widget.storeId,
        existingIds: _items.map((i) => i.inventoryItem.id).toSet(),
        onSelect: (item) {
          setState(() {
            _items.add(_LineItem(inventoryItem: item));
          });
          Navigator.of(context).pop();
        },
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    final stockItems = _items
        .map((i) => {
              'store_inventory_id': i.inventoryItem.id,
              'quantity': i.eaQuantity,
            })
        .toList();

    final ok = await ref.read(inventoryProvider.notifier).bulkStockIn(
          widget.storeId,
          stockItems,
          _reasonCtrl.text.trim().isEmpty ? null : _reasonCtrl.text.trim(),
        );

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (ok) {
      ToastManager().success(context, 'Stock in recorded successfully');
      context.pop();
    } else {
      ToastManager().error(context, 'Failed to save. Please try again.');
    }
  }
}

// ─── Item row ────────────────────────────────────────────────────────────────

class _ItemRow extends StatefulWidget {
  final _LineItem lineItem;
  final void Function(int) onQtyChanged;
  final VoidCallback onUnitToggle;
  final VoidCallback onRemove;

  const _ItemRow({
    required this.lineItem,
    required this.onQtyChanged,
    required this.onUnitToggle,
    required this.onRemove,
  });

  @override
  State<_ItemRow> createState() => _ItemRowState();
}

class _ItemRowState extends State<_ItemRow> {
  late final TextEditingController _qtyCtrl;

  @override
  void initState() {
    super.initState();
    _qtyCtrl = TextEditingController(text: '${widget.lineItem.quantity}');
  }

  @override
  void didUpdateWidget(covariant _ItemRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.lineItem.quantity != widget.lineItem.quantity) {
      final cursorPos = _qtyCtrl.selection;
      _qtyCtrl.text = '${widget.lineItem.quantity}';
      // Restore cursor if still valid
      if (cursorPos.baseOffset <= _qtyCtrl.text.length) {
        _qtyCtrl.selection = cursorPos;
      }
    }
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.lineItem.inventoryItem;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          // Thumbnail
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: item.imageUrl != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(item.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(
                            Icons.inventory_2_outlined,
                            size: 20,
                            color: AppColors.textMuted)),
                  )
                : const Icon(Icons.inventory_2_outlined,
                    size: 20, color: AppColors.textMuted),
          ),
          const SizedBox(width: 10),
          // Name + preview
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (widget.lineItem.hasSubUnit && widget.lineItem.useSubUnit)
                  Text(
                    '= ${widget.lineItem.eaQuantity} ea',
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textSecondary),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Unit toggle
          if (widget.lineItem.hasSubUnit)
            GestureDetector(
              onTap: widget.onUnitToggle,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: widget.lineItem.useSubUnit
                      ? AppColors.accentBg
                      : AppColors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: widget.lineItem.useSubUnit
                        ? AppColors.accent
                        : AppColors.border,
                  ),
                ),
                child: Text(
                  widget.lineItem.useSubUnit ? item.subUnit! : 'ea',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: widget.lineItem.useSubUnit
                        ? AppColors.accent
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          const SizedBox(width: 8),
          // Qty -/+
          _QtyButton(
            icon: Icons.remove,
            onTap: widget.lineItem.quantity > 1
                ? () {
                    final newQty = widget.lineItem.quantity - 1;
                    widget.onQtyChanged(newQty);
                    _qtyCtrl.text = '$newQty';
                  }
                : null,
          ),
          SizedBox(
            width: 48,
            child: TextField(
              controller: _qtyCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text),
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                isDense: true,
              ),
              onChanged: (v) {
                final parsed = int.tryParse(v);
                if (parsed != null && parsed > 0) {
                  widget.onQtyChanged(parsed);
                }
              },
            ),
          ),
          _QtyButton(
            icon: Icons.add,
            onTap: () {
              final newQty = widget.lineItem.quantity + 1;
              widget.onQtyChanged(newQty);
              _qtyCtrl.text = '$newQty';
            },
          ),
          const SizedBox(width: 6),
          // Remove
          GestureDetector(
            onTap: widget.onRemove,
            child: const Icon(Icons.close, size: 18, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _QtyButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _QtyButton({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: onTap != null ? AppColors.accentBg : AppColors.bg,
          shape: BoxShape.circle,
        ),
        child: Icon(icon,
            size: 16,
            color: onTap != null ? AppColors.accent : AppColors.textMuted),
      ),
    );
  }
}

// ─── Product search bottom sheet ─────────────────────────────────────────────

class _ProductSearchSheet extends ConsumerStatefulWidget {
  final String storeId;
  final Set<String> existingIds;
  final void Function(StoreInventoryItem) onSelect;

  const _ProductSearchSheet({
    required this.storeId,
    required this.existingIds,
    required this.onSelect,
  });

  @override
  ConsumerState<_ProductSearchSheet> createState() =>
      _ProductSearchSheetState();
}

class _ProductSearchSheetState
    extends ConsumerState<_ProductSearchSheet> {
  final _searchCtrl = TextEditingController();
  List<StoreInventoryItem>? _results;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _search('');
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _search(String keyword) async {
    setState(() => _isLoading = true);
    try {
      final items = await ref.read(inventoryServiceProvider).getStoreInventory(
            widget.storeId,
            keyword: keyword.isEmpty ? null : keyword,
          );
      if (mounted) setState(() => _results = items);
    } catch (_) {
      if (mounted) setState(() => _results = []);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchCtrl,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Search inventory...',
                prefixIcon: Icon(Icons.search, size: 20, color: AppColors.textMuted),
              ),
              onChanged: (v) => _search(v),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.accent))
                : _results == null || _results!.isEmpty
                    ? Center(
                        child: Text(
                          'No products found',
                          style: const TextStyle(
                              fontSize: 14, color: AppColors.textSecondary),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        itemCount: _results!.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 8),
                        itemBuilder: (context, i) {
                          final item = _results![i];
                          final alreadyAdded =
                              widget.existingIds.contains(item.id);
                          return GestureDetector(
                            onTap: alreadyAdded
                                ? null
                                : () => widget.onSelect(item),
                            child: Opacity(
                              opacity: alreadyAdded ? 0.5 : 1.0,
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.bg,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: AppColors.white,
                                        borderRadius:
                                            BorderRadius.circular(8),
                                      ),
                                      child: const Icon(
                                          Icons.inventory_2_outlined,
                                          size: 18,
                                          color: AppColors.textMuted),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        item.productName,
                                        style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.text),
                                      ),
                                    ),
                                    if (alreadyAdded)
                                      const Text(
                                        'Added',
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: AppColors.textMuted),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
