/// Inventory state management
///
/// InventoryState holds:
///   - stores: list of stores the user belongs to
///   - selectedStore: currently selected InventoryStore
///   - inventoryItems: filtered/sorted list for the current store
///   - summary: in/low/out counts for the current store
///   - selectedItem: item shown in detail bottom sheet
///   - currentAudit: in-progress audit session
///   - isLoading: global loading flag
///   - error: last error message
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/inventory.dart';
import '../services/inventory_service.dart';

class InventoryState {
  final List<InventoryStore> stores;
  final InventoryStore? selectedStore;
  final List<StoreInventoryItem> inventoryItems;
  final InventorySummary summary;
  final StoreInventoryItem? selectedItem;
  final InventoryAudit? currentAudit;
  final bool isLoading;
  final String? error;

  const InventoryState({
    this.stores = const [],
    this.selectedStore,
    this.inventoryItems = const [],
    this.summary = const InventorySummary(
      inStockCount: 0,
      lowStockCount: 0,
      outOfStockCount: 0,
      totalCount: 0,
    ),
    this.selectedItem,
    this.currentAudit,
    this.isLoading = false,
    this.error,
  });

  InventoryState copyWith({
    List<InventoryStore>? stores,
    InventoryStore? selectedStore,
    List<StoreInventoryItem>? inventoryItems,
    InventorySummary? summary,
    StoreInventoryItem? selectedItem,
    InventoryAudit? currentAudit,
    bool? isLoading,
    String? error,
    bool clearSelectedItem = false,
    bool clearAudit = false,
    bool clearError = false,
  }) {
    return InventoryState(
      stores: stores ?? this.stores,
      selectedStore: selectedStore ?? this.selectedStore,
      inventoryItems: inventoryItems ?? this.inventoryItems,
      summary: summary ?? this.summary,
      selectedItem: clearSelectedItem ? null : (selectedItem ?? this.selectedItem),
      currentAudit: clearAudit ? null : (currentAudit ?? this.currentAudit),
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

final inventoryProvider =
    StateNotifierProvider<InventoryNotifier, InventoryState>((ref) {
  return InventoryNotifier(ref.read(inventoryServiceProvider));
});

class InventoryNotifier extends StateNotifier<InventoryState> {
  final InventoryService _service;

  InventoryNotifier(this._service) : super(const InventoryState());

  /// Load stores the user belongs to
  Future<void> loadStores() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final stores = await _service.getMyStores();
      state = state.copyWith(stores: stores, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Select a store and load its summary
  Future<void> selectStore(InventoryStore store) async {
    state = state.copyWith(selectedStore: store, clearError: true);
    await loadSummary(store.id);
  }

  /// Load summary counts for the given store
  Future<void> loadSummary(String storeId) async {
    try {
      final summary = await _service.getStoreSummary(storeId);
      state = state.copyWith(summary: summary);
    } catch (_) {
      // Non-critical: summary display degrades gracefully
    }
  }

  /// Load inventory items for the current store
  Future<void> loadInventory(
    String storeId, {
    String? keyword,
    String? status,
    bool? isFrequent,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final items = await _service.getStoreInventory(
        storeId,
        keyword: keyword,
        status: status,
        isFrequent: isFrequent,
      );
      // Sort: frequent first, then oldest audited first
      items.sort((a, b) {
        if (a.isFrequent != b.isFrequent) {
          return a.isFrequent ? -1 : 1;
        }
        if (a.lastAuditedAt == null && b.lastAuditedAt == null) return 0;
        if (a.lastAuditedAt == null) return -1;
        if (b.lastAuditedAt == null) return 1;
        return a.lastAuditedAt!.compareTo(b.lastAuditedAt!);
      });
      state = state.copyWith(inventoryItems: items, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Set the item displayed in the detail bottom sheet
  void selectItem(StoreInventoryItem item) {
    state = state.copyWith(selectedItem: item);
  }

  void clearSelectedItem() {
    state = state.copyWith(clearSelectedItem: true);
  }

  /// Perform stock in for a single item and reload inventory
  Future<bool> stockIn(
    String storeId,
    String itemId,
    int quantity,
    String? reason,
  ) async {
    try {
      await _service.stockIn(storeId, itemId, quantity, reason);
      await loadInventory(storeId);
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  /// Perform stock out for a single item and reload inventory
  Future<bool> stockOut(
    String storeId,
    String itemId,
    int quantity,
    String? reason,
  ) async {
    try {
      await _service.stockOut(storeId, itemId, quantity, reason);
      await loadInventory(storeId);
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  /// Adjust quantity for a single item
  Future<bool> adjustStock(
    String storeId,
    String itemId,
    int quantity,
    String? reason,
  ) async {
    try {
      await _service.adjustStock(storeId, itemId, quantity, reason);
      // Reload inventory to get updated quantities
      await loadInventory(storeId);
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  /// Bulk stock in — replaces entire list after success
  Future<bool> bulkStockIn(
    String storeId,
    List<Map<String, dynamic>> items,
    String? reason,
  ) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _service.bulkStockIn(storeId, items, reason);
      await loadInventory(storeId);
      await loadSummary(storeId);
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  /// Bulk stock out
  Future<bool> bulkStockOut(
    String storeId,
    List<Map<String, dynamic>> items,
    String? reason,
  ) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _service.bulkStockOut(storeId, items, reason);
      await loadInventory(storeId);
      await loadSummary(storeId);
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  /// Start audit session for the store
  Future<InventoryAudit?> startAudit(String storeId) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final audit = await _service.startAudit(storeId);
      state = state.copyWith(currentAudit: audit, isLoading: false);
      return audit;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return null;
    }
  }

  /// Get audit session detail
  Future<InventoryAudit?> getAudit(String storeId, String auditId) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final audit = await _service.getAudit(storeId, auditId);
      state = state.copyWith(currentAudit: audit, isLoading: false);
      return audit;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return null;
    }
  }

  /// Complete audit
  Future<bool> completeAudit(String storeId, String auditId) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final audit = await _service.completeAudit(storeId, auditId);
      state = state.copyWith(currentAudit: audit, isLoading: false);
      await loadSummary(storeId);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  void clearAudit() {
    state = state.copyWith(clearAudit: true);
  }

  /// Replace item in the list after a single-item operation
  void _replaceItem(StoreInventoryItem updated) {
    final newList = state.inventoryItems
        .map((item) => item.id == updated.id ? updated : item)
        .toList();
    state = state.copyWith(
      inventoryItems: newList,
      selectedItem: state.selectedItem?.id == updated.id
          ? updated
          : state.selectedItem,
    );
  }
}
