/// Store selection screen — entry point for inventory
///
/// Shows a card list of stores the user belongs to.
/// Each card: store name, address, quick stock stats.
/// Tap → navigate to InventoryHomeScreen for the selected store.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../config/theme.dart';
import '../../models/inventory.dart';
import '../../providers/inventory_provider.dart';
import '../../widgets/app_header.dart';

class StoreSelectScreen extends ConsumerStatefulWidget {
  const StoreSelectScreen({super.key});

  @override
  ConsumerState<StoreSelectScreen> createState() => _StoreSelectScreenState();
}

class _StoreSelectScreenState extends ConsumerState<StoreSelectScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(inventoryProvider.notifier).loadStores();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(inventoryProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          AppHeader(
            title: 'Inventory',
            isDetail: true,
            onBack: () => context.pop(),
          ),
          Expanded(
            child: _buildBody(state),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(InventoryState state) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.accent));
    }

    if (state.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: AppColors.textMuted),
              const SizedBox(height: 12),
              Text(
                'Failed to load stores',
                style: const TextStyle(fontSize: 15, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () =>
                    ref.read(inventoryProvider.notifier).loadStores(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (state.stores.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.store_outlined, size: 48, color: AppColors.textMuted),
              const SizedBox(height: 12),
              Text(
                'No stores assigned',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.text),
              ),
              const SizedBox(height: 6),
              Text(
                'You are not assigned to any stores yet.',
                style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.accent,
      onRefresh: () => ref.read(inventoryProvider.notifier).loadStores(),
      child: ListView.separated(
        padding: const EdgeInsets.all(20),
        itemCount: state.stores.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          return _StoreCard(
            store: state.stores[index],
            onTap: () => _selectStore(state.stores[index]),
          );
        },
      ),
    );
  }

  void _selectStore(InventoryStore store) {
    ref.read(inventoryProvider.notifier).selectStore(store);
    context.push('/inventory/${store.id}');
  }
}

class _StoreCard extends StatelessWidget {
  final InventoryStore store;
  final VoidCallback onTap;

  const _StoreCard({required this.store, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            // Store icon
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.accentBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.storefront_rounded, size: 24, color: AppColors.accent),
            ),
            const SizedBox(width: 14),
            // Store info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    store.name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text,
                    ),
                  ),
                  if (store.address != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      store.address!,
                      style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  // Quick stock stats (if available)
                  if (store.totalProducts != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _StockBadge(
                          count: store.totalProducts!,
                          label: 'items',
                          color: AppColors.textMuted,
                        ),
                        if (store.lowStockCount != null && store.lowStockCount! > 0) ...[
                          const SizedBox(width: 8),
                          _StockBadge(
                            count: store.lowStockCount!,
                            label: 'low',
                            color: AppColors.warning,
                          ),
                        ],
                        if (store.outOfStockCount != null && store.outOfStockCount! > 0) ...[
                          const SizedBox(width: 8),
                          _StockBadge(
                            count: store.outOfStockCount!,
                            label: 'out',
                            color: AppColors.danger,
                          ),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, size: 20, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

class _StockBadge extends StatelessWidget {
  final int count;
  final String label;
  final Color color;

  const _StockBadge({required this.count, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '$count $label',
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}
