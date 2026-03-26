/// Inventory home screen — hub for a selected store
///
/// Shows status summary (in/low/out counts) and 4 action buttons:
///   View Inventory → inventory_list
///   Audit          → inventory_audit
///   Stock In       → stock_in
///   Stock Out      → stock_out
/// Low stock alert banner when low/out items exist.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../config/theme.dart';
import '../../models/inventory.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/app_header.dart';

class InventoryHomeScreen extends ConsumerStatefulWidget {
  final String storeId;

  const InventoryHomeScreen({super.key, required this.storeId});

  @override
  ConsumerState<InventoryHomeScreen> createState() =>
      _InventoryHomeScreenState();
}

class _InventoryHomeScreenState
    extends ConsumerState<InventoryHomeScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(inventoryProvider.notifier).loadSummary(widget.storeId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(inventoryProvider);
    final user = ref.watch(authProvider).user;
    final canManage = user != null && user.hasPermission('inventory:create');

    final store = state.selectedStore;
    final summary = state.summary;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          AppHeader(
            title: store?.name ?? 'Inventory',
            isDetail: true,
            onBack: () => context.pop(),
          ),
          Expanded(
            child: RefreshIndicator(
              color: AppColors.accent,
              onRefresh: () => ref
                  .read(inventoryProvider.notifier)
                  .loadSummary(widget.storeId),
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // Change store button
                  _buildChangeStoreRow(context, store),
                  const SizedBox(height: 20),

                  // Status summary cards
                  _buildSummaryCards(summary),
                  const SizedBox(height: 20),

                  // Action grid (2x2)
                  _buildActionGrid(context, canManage),
                  const SizedBox(height: 16),

                  // Low stock alert banner
                  if (summary.lowStockCount + summary.outOfStockCount > 0)
                    _buildLowStockBanner(summary),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChangeStoreRow(BuildContext context, InventoryStore? store) {
    if (store == null) return const SizedBox.shrink();
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                store.name,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.text,
                ),
              ),
              if (store.address != null)
                Text(
                  store.address!,
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
        TextButton.icon(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.swap_horiz, size: 16),
          label: const Text('Change Store'),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.accent,
            textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCards(InventorySummary summary) {
    return Row(
      children: [
        Expanded(
          child: _SummaryCard(
            label: 'In Stock',
            count: summary.inStockCount,
            color: AppColors.success,
            bgColor: AppColors.successBg,
            icon: Icons.check_circle_outline,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _SummaryCard(
            label: 'Low Stock',
            count: summary.lowStockCount,
            color: AppColors.warning,
            bgColor: AppColors.warningBg,
            icon: Icons.warning_amber_outlined,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _SummaryCard(
            label: 'Out',
            count: summary.outOfStockCount,
            color: AppColors.danger,
            bgColor: AppColors.dangerBg,
            icon: Icons.remove_circle_outline,
          ),
        ),
      ],
    );
  }

  Widget _buildActionGrid(BuildContext context, bool canManage) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _ActionCard(
                icon: Icons.inventory_2_outlined,
                label: 'View Inventory',
                color: AppColors.accent,
                bgColor: AppColors.accentBg,
                onTap: () => context.push('/inventory/${widget.storeId}/list'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: canManage
                  ? _ActionCard(
                      icon: Icons.fact_check_outlined,
                      label: 'Audit',
                      color: const Color(0xFF6C5CE7),
                      bgColor: const Color(0xFFF0EDFE),
                      onTap: () =>
                          context.push('/inventory/${widget.storeId}/audit'),
                    )
                  : _ActionCard(
                      icon: Icons.fact_check_outlined,
                      label: 'Audit',
                      color: AppColors.textMuted,
                      bgColor: AppColors.bg,
                      onTap: null,
                    ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: canManage
                  ? _ActionCard(
                      icon: Icons.add_box_outlined,
                      label: 'Stock In',
                      color: AppColors.success,
                      bgColor: AppColors.successBg,
                      onTap: () => context
                          .push('/inventory/${widget.storeId}/stock-in'),
                    )
                  : _ActionCard(
                      icon: Icons.add_box_outlined,
                      label: 'Stock In',
                      color: AppColors.textMuted,
                      bgColor: AppColors.bg,
                      onTap: null,
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: canManage
                  ? _ActionCard(
                      icon: Icons.output_outlined,
                      label: 'Stock Out',
                      color: AppColors.warning,
                      bgColor: AppColors.warningBg,
                      onTap: () => context
                          .push('/inventory/${widget.storeId}/stock-out'),
                    )
                  : _ActionCard(
                      icon: Icons.output_outlined,
                      label: 'Stock Out',
                      color: AppColors.textMuted,
                      bgColor: AppColors.bg,
                      onTap: null,
                    ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLowStockBanner(InventorySummary summary) {
    final total = summary.lowStockCount + summary.outOfStockCount;
    return GestureDetector(
      onTap: () => context.push(
          '/inventory/${widget.storeId}/list?status=low'),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.warningBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded,
                size: 20, color: AppColors.warning),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '$total item${total > 1 ? 's' : ''} need attention',
                style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.text,
                    fontWeight: FontWeight.w500),
              ),
            ),
            Text(
              'View',
              style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.warning,
                  fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Summary card ──────────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final Color bgColor;
  final IconData icon;

  const _SummaryCard({
    required this.label,
    required this.count,
    required this.color,
    required this.bgColor,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(height: 8),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Action card ────────────────────────────────────────────────────────────

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color bgColor;
  final VoidCallback? onTap;

  const _ActionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.bgColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 108,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: onTap != null ? AppColors.white : AppColors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 20, color: color),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: onTap != null ? AppColors.text : AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
