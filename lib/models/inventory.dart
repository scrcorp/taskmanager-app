/// Inventory data models
///
/// InventoryProduct: global product master (inventory_products table)
/// StoreInventoryItem: per-store stock item (store_inventory table)
/// InventoryTransaction: stock in/out/adjustment history
/// InventoryAudit + InventoryAuditItem: audit session and per-item results
/// InventoryStore: store info (from /my/stores)
/// InventorySummary: store-level counts (in/low/out)

/// Category node from /app/inventory/categories
class InventoryCategory {
  final String id;
  final String name;
  final String? parentId;
  final List<InventoryCategory> children;

  const InventoryCategory({
    required this.id,
    required this.name,
    this.parentId,
    this.children = const [],
  });

  factory InventoryCategory.fromJson(Map<String, dynamic> json) {
    final rawChildren = json['children'] as List<dynamic>? ?? [];
    return InventoryCategory(
      id: json['id'] as String,
      name: json['name'] as String,
      parentId: json['parent_id'] as String?,
      children: rawChildren
          .map((e) => InventoryCategory.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// Sub-unit option from /app/inventory/sub-units
class InventorySubUnit {
  final String id;
  final String name;
  final String code;
  final int sortOrder;

  const InventorySubUnit({
    required this.id,
    required this.name,
    required this.code,
    required this.sortOrder,
  });

  factory InventorySubUnit.fromJson(Map<String, dynamic> json) {
    return InventorySubUnit(
      id: json['id'] as String,
      name: json['name'] as String,
      code: json['code'] as String,
      sortOrder: json['sort_order'] as int? ?? 0,
    );
  }
}

/// Status codes for store inventory item
/// normal: current_quantity > min_quantity
/// low: 0 < current_quantity <= min_quantity
/// out: current_quantity <= 0
const kStatusNormal = 'normal';
const kStatusLow = 'low';
const kStatusOut = 'out';

/// Transaction types
const kTxStockIn = 'stock_in';
const kTxStockOut = 'stock_out';
const kTxAdjustment = 'adjustment';

/// Global product master from organization's product catalog
class InventoryProduct {
  final String id;
  final String name;
  final String? code;
  final String? categoryName;
  /// Secondary unit name (e.g. "box", "pack", "case"). Null if counted in ea only.
  final String? subUnit;
  /// How many ea equal 1 sub_unit (e.g. 24 for 1 box = 24 ea)
  final int? subUnitRatio;
  final String? imageUrl;
  final String? description;
  final bool isActive;
  /// Number of stores currently using this product
  final int storeCount;

  const InventoryProduct({
    required this.id,
    required this.name,
    this.code,
    this.categoryName,
    this.subUnit,
    this.subUnitRatio,
    this.imageUrl,
    this.description,
    this.isActive = true,
    this.storeCount = 0,
  });

  factory InventoryProduct.fromJson(Map<String, dynamic> json) {
    return InventoryProduct(
      id: json['id'] as String,
      name: json['name'] as String,
      code: json['code'] as String?,
      categoryName: json['category_name'] as String?,
      subUnit: json['sub_unit'] as String?,
      subUnitRatio: json['sub_unit_ratio'] as int?,
      imageUrl: json['image_url'] as String?,
      description: json['description'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      storeCount: json['store_count'] as int? ?? 0,
    );
  }
}

/// Per-store inventory item combining store_inventory + inventory_products data
class StoreInventoryItem {
  final String id;
  final String storeId;
  final String productId;
  final String productName;
  final String? productCode;
  final String? categoryName;
  final String? subUnit;
  final int? subUnitRatio;
  final String? imageUrl;
  final String? description;
  final int currentQuantity;
  final int minQuantity;
  /// true = needs frequent auditing; sorted to top in list and audit screens
  final bool isFrequent;
  final DateTime? lastAuditedAt;
  final bool isActive;
  /// Computed status: 'normal' | 'low' | 'out'
  final String status;

  const StoreInventoryItem({
    required this.id,
    required this.storeId,
    required this.productId,
    required this.productName,
    this.productCode,
    this.categoryName,
    this.subUnit,
    this.subUnitRatio,
    this.imageUrl,
    this.description,
    required this.currentQuantity,
    this.minQuantity = 0,
    this.isFrequent = false,
    this.lastAuditedAt,
    this.isActive = true,
    this.status = kStatusNormal,
  });

  factory StoreInventoryItem.fromJson(Map<String, dynamic> json) {
    return StoreInventoryItem(
      id: json['id'] as String,
      storeId: json['store_id'] as String,
      productId: json['product_id'] as String,
      productName: json['product_name'] as String,
      productCode: json['product_code'] as String?,
      categoryName: json['category_name'] as String?,
      subUnit: json['sub_unit'] as String?,
      subUnitRatio: json['sub_unit_ratio'] as int?,
      imageUrl: json['image_url'] as String?,
      description: json['description'] as String?,
      currentQuantity: (json['current_quantity'] as num?)?.toInt() ?? 0,
      minQuantity: (json['min_quantity'] as num?)?.toInt() ?? 0,
      isFrequent: json['is_frequent'] as bool? ?? false,
      lastAuditedAt: json['last_audited_at'] != null
          ? DateTime.parse(json['last_audited_at'] as String)
          : null,
      isActive: json['is_active'] as bool? ?? true,
      status: json['status'] as String? ?? kStatusNormal,
    );
  }

  /// Sub-unit display string e.g. "200 ea (4 boxes)"
  String get quantityDisplay {
    if (subUnit != null && subUnitRatio != null && subUnitRatio! > 0) {
      final subQty = currentQuantity ~/ subUnitRatio!;
      return '$currentQuantity ea ($subQty ${subUnit}s)';
    }
    return '$currentQuantity ea';
  }
}

/// Single stock in / stock out / adjustment transaction
class InventoryTransaction {
  final String id;
  final String storeInventoryId;
  final String productName;
  final String? productCode;
  /// 'stock_in' | 'stock_out' | 'adjustment'
  final String type;
  final double quantity;
  final double beforeQuantity;
  final double afterQuantity;
  final String? reason;
  final String createdBy;
  final String? createdByName;
  final DateTime createdAt;

  const InventoryTransaction({
    required this.id,
    required this.storeInventoryId,
    required this.productName,
    this.productCode,
    required this.type,
    required this.quantity,
    required this.beforeQuantity,
    required this.afterQuantity,
    this.reason,
    required this.createdBy,
    this.createdByName,
    required this.createdAt,
  });

  factory InventoryTransaction.fromJson(Map<String, dynamic> json) {
    return InventoryTransaction(
      id: json['id'] as String,
      storeInventoryId: json['store_inventory_id'] as String,
      productName: json['product_name'] as String,
      productCode: json['product_code'] as String?,
      type: json['type'] as String,
      quantity: (json['quantity'] as num).toDouble(),
      beforeQuantity: (json['before_quantity'] as num).toDouble(),
      afterQuantity: (json['after_quantity'] as num).toDouble(),
      reason: json['reason'] as String?,
      createdBy: json['created_by'] as String,
      createdByName: json['created_by_name'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

/// Audit session header
class InventoryAudit {
  final String id;
  final String storeId;
  final String auditedBy;
  final String? auditedByName;
  /// 'in_progress' | 'completed'
  final String status;
  final DateTime startedAt;
  final DateTime? completedAt;
  final String? note;
  final List<InventoryAuditItem> items;

  const InventoryAudit({
    required this.id,
    required this.storeId,
    required this.auditedBy,
    this.auditedByName,
    required this.status,
    required this.startedAt,
    this.completedAt,
    this.note,
    this.items = const [],
  });

  factory InventoryAudit.fromJson(Map<String, dynamic> json) {
    return InventoryAudit(
      id: json['id'] as String,
      storeId: json['store_id'] as String,
      auditedBy: json['audited_by'] as String,
      auditedByName: json['auditor_name'] as String? ?? json['audited_by_name'] as String?,
      status: json['status'] as String? ?? 'in_progress',
      startedAt: DateTime.parse(json['started_at'] as String),
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : null,
      note: json['note'] as String?,
      items: (json['items'] as List<dynamic>?)
              ?.map((e) => InventoryAuditItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

/// Per-item row within an audit session
class InventoryAuditItem {
  final String id;
  final String auditId;
  final String storeInventoryId;
  final String productName;
  final String? productCode;
  final String? subUnit;
  final int? subUnitRatio;
  final bool isFrequent;
  final double systemQuantity;
  double actualQuantity;
  final DateTime? lastAuditedAt;

  InventoryAuditItem({
    required this.id,
    required this.auditId,
    required this.storeInventoryId,
    required this.productName,
    this.productCode,
    this.subUnit,
    this.subUnitRatio,
    this.isFrequent = false,
    required this.systemQuantity,
    required this.actualQuantity,
    this.lastAuditedAt,
  });

  double get difference => actualQuantity - systemQuantity;

  factory InventoryAuditItem.fromJson(Map<String, dynamic> json) {
    return InventoryAuditItem(
      id: json['id'] as String,
      auditId: json['audit_id'] as String? ?? '',
      storeInventoryId: json['store_inventory_id'] as String,
      productName: json['product_name'] as String? ?? '',
      productCode: json['product_code'] as String?,
      subUnit: json['sub_unit'] as String?,
      subUnitRatio: json['sub_unit_ratio'] as int?,
      isFrequent: json['is_frequent'] as bool? ?? false,
      systemQuantity: (json['system_quantity'] as num).toDouble(),
      actualQuantity: (json['actual_quantity'] as num?)?.toDouble() ??
          (json['system_quantity'] as num).toDouble(),
      lastAuditedAt: json['last_audited_at'] != null
          ? DateTime.parse(json['last_audited_at'] as String)
          : null,
    );
  }
}

/// Store info for the store selection screen (from /app/my/stores)
class InventoryStore {
  final String id;
  final String name;
  final String? address;
  final int? totalProducts;
  final int? lowStockCount;
  final int? outOfStockCount;

  const InventoryStore({
    required this.id,
    required this.name,
    this.address,
    this.totalProducts,
    this.lowStockCount,
    this.outOfStockCount,
  });

  factory InventoryStore.fromJson(Map<String, dynamic> json) {
    return InventoryStore(
      id: json['id'] as String,
      name: json['name'] as String,
      address: json['address'] as String?,
      totalProducts: json['total_products'] as int?,
      lowStockCount: json['low_stock_count'] as int?,
      outOfStockCount: json['out_of_stock_count'] as int?,
    );
  }
}

/// Summary counts for a store's inventory status
class InventorySummary {
  final int inStockCount;
  final int lowStockCount;
  final int outOfStockCount;
  final int totalCount;

  const InventorySummary({
    required this.inStockCount,
    required this.lowStockCount,
    required this.outOfStockCount,
    required this.totalCount,
  });

  factory InventorySummary.fromJson(Map<String, dynamic> json) {
    return InventorySummary(
      inStockCount: json['normal'] as int? ?? json['in_stock_count'] as int? ?? 0,
      lowStockCount: json['low'] as int? ?? json['low_stock_count'] as int? ?? 0,
      outOfStockCount: json['out'] as int? ?? json['out_of_stock_count'] as int? ?? 0,
      totalCount: json['total'] as int? ?? json['total_count'] as int? ?? 0,
    );
  }

  factory InventorySummary.empty() {
    return const InventorySummary(
      inStockCount: 0,
      lowStockCount: 0,
      outOfStockCount: 0,
      totalCount: 0,
    );
  }
}
