/// Inventory API service
///
/// Handles all inventory-related API calls for the staff app.
/// Endpoints:
///   GET  /app/my/stores                                         — stores the user belongs to
///   GET  /app/stores/{storeId}/inventory                        — store inventory list
///   GET  /app/stores/{storeId}/inventory/summary                — in/low/out counts
///   POST /app/stores/{storeId}/inventory                        — add products to store
///   GET  /app/inventory/categories                             — category tree
///   GET  /app/inventory/sub-units                              — sub-unit options
///   GET  /app/inventory/products                                — search global product catalog
///   POST /app/inventory/products                                — create new product
///   POST /app/stores/{storeId}/inventory/{itemId}/stock-in      — single item stock in
///   POST /app/stores/{storeId}/inventory/{itemId}/stock-out     — single item stock out
///   POST /app/stores/{storeId}/inventory/bulk-stock-in          — multi-item stock in
///   POST /app/stores/{storeId}/inventory/bulk-stock-out         — multi-item stock out
///   POST /app/stores/{storeId}/inventory/audits                 — start audit
///   GET  /app/stores/{storeId}/inventory/audits/{auditId}       — get audit detail
///   PUT  /app/stores/{storeId}/inventory/audits/{auditId}/items — update audit item quantities
///   POST /app/stores/{storeId}/inventory/audits/{auditId}/complete — complete audit
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/inventory.dart';
import 'api_client.dart';

final inventoryServiceProvider = Provider<InventoryService>((ref) {
  return InventoryService(ref.read(dioProvider));
});

class InventoryService {
  final Dio _dio;

  InventoryService(this._dio);

  /// Stores the user manages (is_manager=true) for inventory access
  Future<List<InventoryStore>> getMyStores() async {
    final response = await _dio.get('/app/inventory/my-stores');
    final list = response.data is List
        ? response.data
        : response.data['items'] ?? response.data['data'] ?? [];
    return (list as List)
        .map((e) => InventoryStore.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Store inventory list with optional filters
  Future<List<StoreInventoryItem>> getStoreInventory(
    String storeId, {
    String? keyword,
    String? status,
    bool? isFrequent,
    int page = 1,
  }) async {
    final params = <String, dynamic>{'page': page};
    if (keyword != null && keyword.isNotEmpty) params['keyword'] = keyword;
    if (status != null && status.isNotEmpty) params['status'] = status;
    if (isFrequent != null) params['is_frequent'] = isFrequent;

    final response = await _dio.get(
      '/app/stores/$storeId/inventory',
      queryParameters: params,
    );
    final list = response.data is List
        ? response.data
        : response.data['items'] ?? response.data['data'] ?? [];
    return (list as List)
        .map((e) => StoreInventoryItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Summary counts for in/low/out stock
  Future<InventorySummary> getStoreSummary(String storeId) async {
    final response =
        await _dio.get('/app/stores/$storeId/inventory/summary');
    return InventorySummary.fromJson(response.data as Map<String, dynamic>);
  }

  /// Add existing products to a store's inventory
  ///
  /// [items] — list of { product_id, min_quantity, initial_quantity, is_frequent }
  Future<void> addProductsToStore(
    String storeId,
    List<Map<String, dynamic>> items,
  ) async {
    await _dio.post('/app/stores/$storeId/inventory', data: {'items': items});
  }

  /// Search global product catalog (for add-product screen)
  Future<List<InventoryProduct>> searchProducts({String? keyword}) async {
    final params = <String, dynamic>{};
    if (keyword != null && keyword.isNotEmpty) params['keyword'] = keyword;
    final response = await _dio.get('/app/inventory/products',
        queryParameters: params);
    final list = response.data is List
        ? response.data
        : response.data['items'] ?? response.data['data'] ?? [];
    return (list as List)
        .map((e) => InventoryProduct.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Category tree from /app/inventory/categories
  ///
  /// Returns top-level categories with nested children.
  Future<List<InventoryCategory>> getCategories() async {
    final response = await _dio.get('/app/inventory/categories');
    final list = response.data is List
        ? response.data
        : response.data['items'] ?? response.data['data'] ?? [];
    return (list as List)
        .map((e) => InventoryCategory.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Sub-unit options from /app/inventory/sub-units
  Future<List<InventorySubUnit>> getSubUnits() async {
    final response = await _dio.get('/app/inventory/sub-units');
    final list = response.data is List
        ? response.data
        : response.data['items'] ?? response.data['data'] ?? [];
    return (list as List)
        .map((e) => InventorySubUnit.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Create a category (returns {id, name, ...})
  Future<Map<String, dynamic>> createCategory(String name, {String? parentId}) async {
    final response = await _dio.post('/app/inventory/categories', data: {
      'name': name,
      if (parentId != null) 'parent_id': parentId,
    });
    return response.data as Map<String, dynamic>;
  }

  /// Create a sub unit (returns {id, name, code, ...})
  Future<Map<String, dynamic>> createSubUnit(String name) async {
    final response = await _dio.post('/app/inventory/sub-units', data: {
      'name': name,
      'code': name.toLowerCase().replaceAll(RegExp(r'\s+'), '_'),
    });
    return response.data as Map<String, dynamic>;
  }

  /// Create a new product in the organization's catalog
  Future<InventoryProduct> createProduct(Map<String, dynamic> data) async {
    final response =
        await _dio.post('/app/inventory/products', data: data);
    return InventoryProduct.fromJson(response.data as Map<String, dynamic>);
  }

  /// Individual stock in for a single inventory item
  Future<void> stockIn(
    String storeId,
    String itemId,
    int quantity,
    String? reason,
  ) async {
    await _dio.post(
      '/app/stores/$storeId/inventory/$itemId/stock-in',
      data: {
        'type': 'stock_in',
        'quantity': quantity,
        if (reason != null && reason.isNotEmpty) 'reason': reason,
      },
    );
  }

  /// Individual stock out for a single inventory item
  Future<void> stockOut(
    String storeId,
    String itemId,
    int quantity,
    String? reason,
  ) async {
    await _dio.post(
      '/app/stores/$storeId/inventory/$itemId/stock-out',
      data: {
        'type': 'stock_out',
        'quantity': quantity,
        if (reason != null && reason.isNotEmpty) 'reason': reason,
      },
    );
  }

  /// Adjust (set actual quantity) for a single inventory item — creates adjustment transaction
  Future<void> adjustStock(
    String storeId,
    String itemId,
    int actualQuantity,
    String? reason,
  ) async {
    await _dio.post(
      '/app/stores/$storeId/inventory/$itemId/adjust',
      data: {
        'type': 'adjustment',
        'quantity': actualQuantity,
        if (reason != null && reason.isNotEmpty) 'reason': reason,
      },
    );
  }

  /// Bulk stock in — multiple items in one request
  ///
  /// [items] — list of { store_inventory_id, quantity, reason? }
  Future<void> bulkStockIn(
    String storeId,
    List<Map<String, dynamic>> items,
    String? reason,
  ) async {
    await _dio.post(
      '/app/stores/$storeId/inventory/bulk-stock-in',
      data: {
        'type': 'stock_in',
        'items': items,
        if (reason != null && reason.isNotEmpty) 'reason': reason,
      },
    );
  }

  /// Bulk stock out — multiple items in one request
  Future<void> bulkStockOut(
    String storeId,
    List<Map<String, dynamic>> items,
    String? reason,
  ) async {
    await _dio.post(
      '/app/stores/$storeId/inventory/bulk-stock-out',
      data: {
        'type': 'stock_out',
        'items': items,
        if (reason != null && reason.isNotEmpty) 'reason': reason,
      },
    );
  }

  /// Submit a completed audit in one shot — creates audit + items + transactions
  ///
  /// [items] — list of { store_inventory_id, actual_quantity }
  /// [note]  — optional audit note
  Future<InventoryAudit> submitAudit(
    String storeId,
    List<Map<String, dynamic>> items, {
    String? note,
  }) async {
    final response = await _dio.post(
      '/app/stores/$storeId/inventory/audits',
      data: {
        'items': items,
        if (note != null && note.isNotEmpty) 'note': note,
      },
    );
    return InventoryAudit.fromJson(response.data as Map<String, dynamic>);
  }

  /// Start a new audit session for the store
  Future<InventoryAudit> startAudit(String storeId) async {
    final response =
        await _dio.post('/app/stores/$storeId/inventory/audits', data: {});
    return InventoryAudit.fromJson(response.data as Map<String, dynamic>);
  }

  /// Get audit session detail including items
  Future<InventoryAudit> getAudit(String storeId, String auditId) async {
    final response = await _dio
        .get('/app/stores/$storeId/inventory/audits/$auditId');
    return InventoryAudit.fromJson(response.data as Map<String, dynamic>);
  }

  /// Update actual quantities for audit items
  ///
  /// [items] — list of { id, actual_quantity }
  Future<InventoryAudit> updateAuditItems(
    String storeId,
    String auditId,
    List<Map<String, dynamic>> items,
  ) async {
    final response = await _dio.put(
      '/app/stores/$storeId/inventory/audits/$auditId/items',
      data: {'items': items},
    );
    return InventoryAudit.fromJson(response.data as Map<String, dynamic>);
  }

  /// Complete audit — applies all differences as adjustment transactions
  Future<InventoryAudit> completeAudit(
      String storeId, String auditId) async {
    final response = await _dio.post(
        '/app/stores/$storeId/inventory/audits/$auditId/complete',
        data: {});
    return InventoryAudit.fromJson(response.data as Map<String, dynamic>);
  }
}
