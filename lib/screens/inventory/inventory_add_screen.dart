/// Add Product screen — add products to a store's inventory
///
/// Two flows:
///   1. Search existing products → select → set min_qty + initial_qty + is_frequent → "Add to Store"
///   2. "Create New Product" → full form (image, name, category, sub_unit, description,
///      min_qty, initial_qty, is_frequent) → creates product and adds to store
///
/// Categories and sub-units are loaded from server on init.
/// Image upload uses presigned URL pattern (no multipart).
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../config/theme.dart';
import '../../models/inventory.dart';
import '../../providers/inventory_provider.dart';
import '../../services/inventory_service.dart';
import '../../services/storage_service.dart';
import '../../widgets/app_header.dart';
import '../../utils/toast_manager.dart';

class InventoryAddScreen extends ConsumerStatefulWidget {
  final String storeId;

  const InventoryAddScreen({super.key, required this.storeId});

  @override
  ConsumerState<InventoryAddScreen> createState() => _InventoryAddScreenState();
}

class _InventoryAddScreenState extends ConsumerState<InventoryAddScreen> {
  final _searchCtrl = TextEditingController();
  List<InventoryProduct>? _searchResults;
  bool _isSearching = false;
  InventoryProduct? _selectedProduct;
  bool _showCreateForm = false;

  // Add-to-store fields
  final _minQtyCtrl = TextEditingController(text: '0');
  final _initialQtyCtrl = TextEditingController(text: '0');
  bool _isFrequent = false;

  // Create-new-product fields
  final _nameCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _subUnitRatioCtrl = TextEditingController(text: '1');
  final _descriptionCtrl = TextEditingController();
  final _newMinQtyCtrl = TextEditingController(text: '0');
  final _newInitialQtyCtrl = TextEditingController(text: '0');
  bool _newIsFrequent = false;
  bool _isSaving = false;
  bool _hasSubmitted = false;

  // Image upload state
  Uint8List? _productImage;
  String? _uploadedImageKey; // relative path returned from presigned upload
  bool _isUploadingImage = false;
  final _picker = ImagePicker();

  // Server-loaded categories
  List<InventoryCategory> _categories = [];
  bool _loadingCategories = true;
  String? _selectedCategoryId;
  String? _selectedSubcategoryId;
  // "add new" inline flow for category
  bool _addingCategory = false;
  final _newCategoryCtrl = TextEditingController();

  // Server-loaded sub-units
  List<InventorySubUnit> _subUnits = [];
  bool _loadingSubUnits = true;
  InventorySubUnit? _selectedSubUnit;
  // "add new" inline flow for sub-unit (custom string, not persisted to server)
  bool _addingSubUnit = false;
  final _newSubUnitCtrl = TextEditingController();
  // Custom sub-units entered by user (not from server)
  final List<InventorySubUnit> _customSubUnits = [];

  // Existing store inventory product IDs (for "already added" dimming)
  Set<String> _existingProductIds = {};

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _searchProducts('');
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _minQtyCtrl.dispose();
    _initialQtyCtrl.dispose();
    _nameCtrl.dispose();
    _codeCtrl.dispose();
    _subUnitRatioCtrl.dispose();
    _newSubUnitCtrl.dispose();
    _newCategoryCtrl.dispose();
    _descriptionCtrl.dispose();
    _newMinQtyCtrl.dispose();
    _newInitialQtyCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    await Future.wait([
      _loadExistingItems(),
      _loadCategories(),
      _loadSubUnits(),
    ]);
  }

  Future<void> _loadExistingItems() async {
    try {
      final items = await ref
          .read(inventoryServiceProvider)
          .getStoreInventory(widget.storeId);
      if (mounted) {
        setState(() {
          _existingProductIds = items.map((i) => i.productId).toSet();
        });
      }
    } catch (_) {}
  }

  Future<void> _loadCategories() async {
    try {
      final cats = await ref.read(inventoryServiceProvider).getCategories();
      if (mounted) setState(() { _categories = cats; _loadingCategories = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingCategories = false);
    }
  }

  Future<void> _loadSubUnits() async {
    try {
      final units = await ref.read(inventoryServiceProvider).getSubUnits();
      if (mounted) setState(() { _subUnits = units; _loadingSubUnits = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingSubUnits = false);
    }
  }

  Future<void> _searchProducts(String keyword) async {
    setState(() => _isSearching = true);
    try {
      final results = await ref
          .read(inventoryServiceProvider)
          .searchProducts(keyword: keyword.isEmpty ? null : keyword);
      if (mounted) setState(() => _searchResults = results);
    } catch (_) {
      if (mounted) setState(() => _searchResults = []);
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  Future<void> _pickProductImage() async {
    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2)),
              ),
              const Text('Product Image',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text)),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                      color: AppColors.accentBg,
                      borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.camera_alt,
                      color: AppColors.accent, size: 20),
                ),
                title: const Text('Take Photo', style: TextStyle(fontSize: 15)),
                onTap: () {
                  Navigator.pop(ctx);
                  _getProductImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                      color: AppColors.accentBg,
                      borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.photo_library,
                      color: AppColors.accent, size: 20),
                ),
                title: const Text('Choose from Gallery',
                    style: TextStyle(fontSize: 15)),
                onTap: () {
                  Navigator.pop(ctx);
                  _getProductImage(ImageSource.gallery);
                },
              ),
              if (_productImage != null)
                ListTile(
                  leading: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                        color: AppColors.dangerBg,
                        borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.delete_outline,
                        color: AppColors.danger, size: 20),
                  ),
                  title: const Text('Remove Photo',
                      style: TextStyle(fontSize: 15, color: AppColors.danger)),
                  onTap: () {
                    Navigator.pop(ctx);
                    setState(() {
                      _productImage = null;
                      _uploadedImageKey = null;
                    });
                  },
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  /// Pick image bytes then immediately upload via presigned URL.
  /// Stores the returned relative key in [_uploadedImageKey].
  Future<void> _getProductImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
          source: source, maxWidth: 800, maxHeight: 800, imageQuality: 85);
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      final filename = picked.name.isNotEmpty ? picked.name : 'product_image.jpg';
      setState(() {
        _productImage = bytes;
        _uploadedImageKey = null;
        _isUploadingImage = true;
      });
      // Upload via presigned URL — same pattern as checklist photo upload
      final storageService = ref.read(storageServiceProvider);
      final urls = await storageService.getPresignedUrl(
        filename,
        'image/jpeg',
        folder: 'products',
      );
      await storageService.uploadFile(urls['upload_url']!, bytes, 'image/jpeg');
      if (mounted) {
        setState(() {
          _uploadedImageKey = urls['file_url'];
          _isUploadingImage = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isUploadingImage = false);
        ToastManager().error(context, 'Image upload failed');
      }
    }
  }

  // ── Subcategories for the selected top-level category ──────────────────────

  List<InventoryCategory> get _subcategoriesForSelected {
    if (_selectedCategoryId == null) return [];
    final parent = _categories.where((c) => c.id == _selectedCategoryId).firstOrNull;
    return parent?.children ?? [];
  }

  // ── All sub-unit options (server + custom) ─────────────────────────────────

  List<InventorySubUnit> get _allSubUnits => [..._subUnits, ..._customSubUnits];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          AppHeader(
            title: 'Add Product',
            isDetail: true,
            onBack: () => context.pop(),
          ),
          Expanded(
            child: _showCreateForm
                ? _buildCreateForm()
                : _buildSearchSection(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchSection() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Search bar
        TextField(
          controller: _searchCtrl,
          decoration: const InputDecoration(
            hintText: 'Search products by name or code...',
            prefixIcon: Icon(Icons.search, size: 20, color: AppColors.textMuted),
          ),
          onChanged: (v) => _searchProducts(v),
        ),
        const SizedBox(height: 12),
        // "Create new" button
        GestureDetector(
          onTap: () => setState(() => _showCreateForm = true),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.accentBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.add_circle_outline, size: 18, color: AppColors.accent),
                SizedBox(width: 8),
                Text(
                  'Create New Product',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.accent),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Results
        if (_isSearching)
          const Center(child: CircularProgressIndicator(color: AppColors.accent))
        else if (_searchResults != null)
          ..._searchResults!.map((product) {
            final alreadyAdded = _existingProductIds.contains(product.id);
            final isSelected = _selectedProduct?.id == product.id;
            return Column(
              children: [
                GestureDetector(
                  onTap: alreadyAdded
                      ? null
                      : () => setState(() {
                            _selectedProduct = isSelected ? null : product;
                          }),
                  child: Opacity(
                    opacity: alreadyAdded ? 0.5 : 1.0,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.accentBg : AppColors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected ? AppColors.accent : AppColors.border,
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44, height: 44,
                            decoration: BoxDecoration(
                              color: AppColors.bg,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: product.imageUrl != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(product.imageUrl!,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => const Icon(
                                            Icons.inventory_2_outlined,
                                            size: 20,
                                            color: AppColors.textMuted)),
                                  )
                                : const Icon(Icons.inventory_2_outlined,
                                    size: 20, color: AppColors.textMuted),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  product.name,
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: alreadyAdded
                                          ? AppColors.textMuted
                                          : AppColors.text),
                                ),
                                if (product.description != null)
                                  Text(
                                    product.description!,
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                if (product.categoryName != null)
                                  Text(
                                    product.categoryName!,
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textMuted),
                                  ),
                              ],
                            ),
                          ),
                          if (alreadyAdded)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.bg,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'Already Added',
                                style: TextStyle(
                                    fontSize: 11, color: AppColors.textMuted),
                              ),
                            )
                          else if (isSelected)
                            const Icon(Icons.check_circle,
                                size: 20, color: AppColors.accent),
                        ],
                      ),
                    ),
                  ),
                ),
                // Selected product: show min/initial/frequent inputs inline
                if (isSelected && !alreadyAdded) _buildAddToStorePanel(product),
              ],
            );
          }),
      ],
    );
  }

  Widget _buildAddToStorePanel(InventoryProduct product) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.accentBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _LabeledNumberField(
                  label: 'Min Quantity',
                  controller: _minQtyCtrl,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _LabeledNumberField(
                  label: 'Initial Quantity',
                  controller: _initialQtyCtrl,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Checkbox(
                value: _isFrequent,
                onChanged: (v) => setState(() => _isFrequent = v ?? false),
                activeColor: AppColors.accent,
              ),
              const Text('Frequent audit',
                  style: TextStyle(fontSize: 14, color: AppColors.text)),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSaving ? null : () => _addExistingProduct(product),
              child: _isSaving
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Text('Add to Store'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreateForm() {
    final nameEmpty = _hasSubmitted && _nameCtrl.text.trim().isEmpty;
    final categoryEmpty = _hasSubmitted && _selectedCategoryId == null;
    final subUnitSelected = _selectedSubUnit != null;
    final ratioEmpty = _hasSubmitted &&
        subUnitSelected &&
        (_subUnitRatioCtrl.text.trim().isEmpty ||
            (int.tryParse(_subUnitRatioCtrl.text.trim()) ?? 0) <= 0);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          children: [
            GestureDetector(
              onTap: () => setState(() {
                _showCreateForm = false;
                _hasSubmitted = false;
              }),
              child: const Icon(Icons.arrow_back, size: 22, color: AppColors.text),
            ),
            const SizedBox(width: 12),
            const Text(
              'Create New Product',
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // ── 1. Image upload ────────────────────────────────────────────────
        _buildFormCard(children: [
          const Text(
            'Product Image',
            style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: _isUploadingImage ? null : _pickProductImage,
            child: _productImage != null
                ? Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.memory(
                          _productImage!,
                          width: double.infinity,
                          height: 160,
                          fit: BoxFit.cover,
                        ),
                      ),
                      if (_isUploadingImage)
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.4),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Center(
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2),
                            ),
                          ),
                        )
                      else
                        Positioned(
                          top: 8, right: 8,
                          child: Container(
                            width: 32, height: 32,
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.5),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.edit,
                                size: 16, color: Colors.white),
                          ),
                        ),
                    ],
                  )
                : Container(
                    width: double.infinity,
                    height: 120,
                    decoration: BoxDecoration(
                      color: AppColors.bg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border, width: 1.5),
                    ),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_photo_alternate_outlined,
                            size: 32, color: AppColors.textMuted),
                        SizedBox(height: 8),
                        Text('Tap to add photo',
                            style: TextStyle(
                                fontSize: 13, color: AppColors.textMuted)),
                        SizedBox(height: 2),
                        Text('Camera or Gallery',
                            style: TextStyle(
                                fontSize: 11, color: AppColors.textMuted)),
                      ],
                    ),
                  ),
          ),
        ]),
        const SizedBox(height: 16),

        // ── 2-4. Basic info: name, code, category, subcategory ─────────────
        _buildFormCard(children: [
          // Product Name *
          _FormField(
            label: 'Product Name *',
            child: TextField(
              controller: _nameCtrl,
              decoration: InputDecoration(
                hintText: 'e.g. Whole Milk (1L)',
                enabledBorder: nameEmpty
                    ? OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                            color: AppColors.danger, width: 1.5),
                      )
                    : null,
                focusedBorder: nameEmpty
                    ? OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                            color: AppColors.danger, width: 1.5),
                      )
                    : null,
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          if (nameEmpty) ...[
            const SizedBox(height: 4),
            const Text('Product name is required',
                style: TextStyle(fontSize: 11, color: AppColors.danger)),
          ],
          const SizedBox(height: 12),
          // Product Code
          _FormField(
            label: 'Product Code',
            child: TextField(
              controller: _codeCtrl,
              decoration: const InputDecoration(
                  hintText: 'Auto-generated if empty'),
            ),
          ),
          const SizedBox(height: 12),
          // Category *
          _FormField(
            label: 'Category *',
            child: _buildCategorySelector(categoryEmpty),
          ),
          if (categoryEmpty) ...[
            const SizedBox(height: 4),
            const Text('Category is required',
                style: TextStyle(fontSize: 11, color: AppColors.danger)),
          ],
          const SizedBox(height: 12),
          // Subcategory (optional, filtered by selected category)
          _FormField(
            label: 'Subcategory',
            child: _buildSubcategorySelector(),
          ),
        ]),
        const SizedBox(height: 16),

        // ── 5-6. Sub unit ──────────────────────────────────────────────────
        _buildFormCard(children: [
          const Text(
            'Sub Unit',
            style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text),
          ),
          const SizedBox(height: 4),
          const Text(
            'Leave empty if counted only in ea',
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
          const SizedBox(height: 12),
          _buildSubUnitSelector(),
          if (subUnitSelected) ...[
            const SizedBox(height: 12),
            // Sub Unit Ratio *
            _FormField(
              label: 'Sub Unit Ratio *',
              child: TextField(
                controller: _subUnitRatioCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  hintText:
                      '1 ${_selectedSubUnit!.name} = ? ea (e.g. 24)',
                  enabledBorder: ratioEmpty
                      ? OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                              color: AppColors.danger, width: 1.5),
                        )
                      : null,
                  focusedBorder: ratioEmpty
                      ? OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                              color: AppColors.danger, width: 1.5),
                        )
                      : null,
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            if (ratioEmpty) ...[
              const SizedBox(height: 4),
              const Text('Ratio must be greater than 0',
                  style: TextStyle(fontSize: 11, color: AppColors.danger)),
            ],
          ],
        ]),
        const SizedBox(height: 16),

        // ── 7. Description ────────────────────────────────────────────────
        _buildFormCard(children: [
          _FormField(
            label: 'Description',
            child: TextField(
              controller: _descriptionCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                  hintText: 'Short product description'),
            ),
          ),
        ]),
        const SizedBox(height: 16),

        // ── separator + 8-10. Store settings ──────────────────────────────
        _buildFormCard(children: [
          const Text(
            'Store Settings',
            style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _LabeledNumberField(
                  label: 'Min Quantity',
                  controller: _newMinQtyCtrl,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _LabeledNumberField(
                  label: 'Initial Quantity',
                  controller: _newInitialQtyCtrl,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Checkbox(
                value: _newIsFrequent,
                onChanged: (v) => setState(() => _newIsFrequent = v ?? false),
                activeColor: AppColors.accent,
              ),
              const Text('Frequent audit',
                  style: TextStyle(fontSize: 14, color: AppColors.text)),
            ],
          ),
        ]),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: (_isSaving || _isUploadingImage)
                ? null
                : _onCreateAndAddTapped,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: (_isSaving || _isUploadingImage)
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : const Text('Create & Add to Store',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700)),
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  // ── Category selector (server-loaded, top-level) ───────────────────────────

  Widget _buildCategorySelector(bool hasError) {
    if (_loadingCategories) {
      return const SizedBox(
        height: 48,
        child: Center(
          child: SizedBox(
            width: 18, height: 18,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: AppColors.accent),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          value: _selectedCategoryId,
          decoration: InputDecoration(
            hintText: 'Select category',
            enabledBorder: hasError
                ? OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide:
                        const BorderSide(color: AppColors.danger, width: 1.5),
                  )
                : null,
            focusedBorder: hasError
                ? OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide:
                        const BorderSide(color: AppColors.danger, width: 1.5),
                  )
                : null,
          ),
          items: [
            ..._categories.map((c) => DropdownMenuItem(
                  value: c.id,
                  child: Text(c.name),
                )),
            const DropdownMenuItem(
                value: '__add_new__', child: Text('+ Add New')),
          ],
          onChanged: (val) {
            if (val == '__add_new__') {
              setState(() => _addingCategory = true);
            } else {
              setState(() {
                _addingCategory = false;
                _selectedCategoryId = val;
                // Reset subcategory when parent changes
                _selectedSubcategoryId = null;
              });
            }
          },
        ),
        if (_addingCategory) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _newCategoryCtrl,
                  autofocus: true,
                  decoration: const InputDecoration(
                    hintText: 'e.g. Produce, Snacks...',
                    isDense: true,
                  ),
                  onSubmitted: (_) => _addNewCategory(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _addNewCategory,
                icon: const Icon(Icons.check, color: AppColors.accent),
                style: IconButton.styleFrom(
                    backgroundColor: AppColors.accentBg),
              ),
              IconButton(
                onPressed: () => setState(() {
                  _addingCategory = false;
                  _newCategoryCtrl.clear();
                }),
                icon: const Icon(Icons.close, color: AppColors.textMuted),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Future<void> _addNewCategory() async {
    final val = _newCategoryCtrl.text.trim();
    if (val.isEmpty) return;
    final normalized = val[0].toUpperCase() + val.substring(1);
    if (_categories.any((c) => c.name.toLowerCase() == normalized.toLowerCase())) {
      ToastManager().error(context, '"$normalized" already exists');
      return;
    }
    try {
      // Call server API to create category → get UUID back
      final result = await ref.read(inventoryServiceProvider).createCategory(normalized);
      final newId = result['id'] as String;
      final newCat = InventoryCategory(id: newId, name: normalized);
      setState(() {
        _categories = [..._categories, newCat];
        _selectedCategoryId = newId;
        _addingCategory = false;
        _newCategoryCtrl.clear();
      });
    } catch (e) {
      if (!mounted) return;
      ToastManager().error(context, 'Failed to create category');
    }
  }

  // ── Subcategory selector (children of selected category) ──────────────────

  Widget _buildSubcategorySelector() {
    final subs = _subcategoriesForSelected;
    if (_selectedCategoryId == null || subs.isEmpty) {
      return const SizedBox(
        height: 48,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Select a category first',
            style: TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
        ),
      );
    }

    return DropdownButtonFormField<String>(
      value: _selectedSubcategoryId,
      decoration: const InputDecoration(hintText: 'None'),
      items: [
        const DropdownMenuItem<String>(value: null, child: Text('None')),
        ...subs.map((c) => DropdownMenuItem(
              value: c.id,
              child: Text(c.name),
            )),
      ],
      onChanged: (val) => setState(() => _selectedSubcategoryId = val),
    );
  }

  // ── Sub-unit selector (server-loaded + add new) ────────────────────────────

  Widget _buildSubUnitSelector() {
    if (_loadingSubUnits) {
      return const SizedBox(
        height: 48,
        child: Center(
          child: SizedBox(
            width: 18, height: 18,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: AppColors.accent),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          value: _selectedSubUnit?.id,
          decoration: const InputDecoration(
            hintText: 'None (ea only)',
          ),
          items: [
            const DropdownMenuItem<String>(value: null, child: Text('None (ea only)')),
            ..._allSubUnits.map((u) => DropdownMenuItem(
                  value: u.id,
                  child: Text(u.name[0].toUpperCase() + u.name.substring(1)),
                )),
            const DropdownMenuItem(
                value: '__add_new__', child: Text('+ Add New')),
          ],
          onChanged: (val) {
            if (val == '__add_new__') {
              setState(() => _addingSubUnit = true);
            } else if (val == null) {
              setState(() {
                _addingSubUnit = false;
                _selectedSubUnit = null;
                _subUnitRatioCtrl.text = '';
              });
            } else {
              final unit = _allSubUnits.firstWhere((u) => u.id == val);
              setState(() {
                _addingSubUnit = false;
                _selectedSubUnit = unit;
                // Auto-fill ratio to 1 if empty
                if (_subUnitRatioCtrl.text.trim().isEmpty) {
                  _subUnitRatioCtrl.text = '1';
                }
              });
            }
          },
        ),
        if (_addingSubUnit) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _newSubUnitCtrl,
                  autofocus: true,
                  decoration: const InputDecoration(
                    hintText: 'e.g. crate, tray...',
                    isDense: true,
                  ),
                  onSubmitted: (_) => _addNewSubUnit(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _addNewSubUnit,
                icon: const Icon(Icons.check, color: AppColors.accent),
                style: IconButton.styleFrom(
                    backgroundColor: AppColors.accentBg),
              ),
              IconButton(
                onPressed: () => setState(() {
                  _addingSubUnit = false;
                  _newSubUnitCtrl.clear();
                }),
                icon: const Icon(Icons.close, color: AppColors.textMuted),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Future<void> _addNewSubUnit() async {
    final val = _newSubUnitCtrl.text.trim().toLowerCase();
    if (val.isEmpty) return;
    if (_allSubUnits.any((u) => u.code == val)) {
      ToastManager().error(context, '"$val" already exists');
      return;
    }
    try {
      // Call server API to create sub unit → get UUID + code back
      final result = await ref.read(inventoryServiceProvider).createSubUnit(val);
      final newUnit = InventorySubUnit(
        id: result['id'] as String,
        name: result['name'] as String? ?? val,
        code: result['code'] as String? ?? val,
        sortOrder: 999,
      );
      setState(() {
        _customSubUnits.add(newUnit);
        _selectedSubUnit = newUnit;
        _subUnitRatioCtrl.text = '1';
        _addingSubUnit = false;
        _newSubUnitCtrl.clear();
      });
    } catch (e) {
      if (!mounted) return;
      ToastManager().error(context, 'Failed to create sub unit');
    }
  }

  Widget _buildFormCard({required List<Widget> children}) {
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
        children: children,
      ),
    );
  }

  Future<void> _addExistingProduct(InventoryProduct product) async {
    setState(() => _isSaving = true);
    try {
      await ref.read(inventoryServiceProvider).addProductsToStore(
        widget.storeId,
        [
          {
            'product_id': product.id,
            'min_quantity': int.tryParse(_minQtyCtrl.text) ?? 0,
            'initial_quantity': int.tryParse(_initialQtyCtrl.text) ?? 0,
            'is_frequent': _isFrequent,
          },
        ],
      );
      if (!mounted) return;
      await ref.read(inventoryProvider.notifier).loadInventory(widget.storeId);
      await ref.read(inventoryProvider.notifier).loadSummary(widget.storeId);
      ToastManager().success(context, '${product.name} added to store');
      context.pop();
    } catch (_) {
      if (!mounted) return;
      ToastManager().error(context, 'Failed to add product');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _onCreateAndAddTapped() {
    setState(() => _hasSubmitted = true);

    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    if (_selectedCategoryId == null) return;
    if (_selectedSubUnit != null) {
      final ratio = int.tryParse(_subUnitRatioCtrl.text.trim()) ?? 0;
      if (ratio <= 0) return;
    }
    if (_isUploadingImage) return;

    _createAndAdd();
  }

  Future<void> _createAndAdd() async {
    final name = _nameCtrl.text.trim();
    final code = _codeCtrl.text.trim();
    final description = _descriptionCtrl.text.trim();
    final ratio = int.tryParse(_subUnitRatioCtrl.text.trim());
    final minQty = int.tryParse(_newMinQtyCtrl.text) ?? 0;
    final initialQty = int.tryParse(_newInitialQtyCtrl.text) ?? 0;

    setState(() => _isSaving = true);
    try {
      final data = <String, dynamic>{
        'name': name,
        if (code.isNotEmpty) 'code': code,
        'category_id': _selectedCategoryId,
        if (_selectedSubcategoryId != null)
          'subcategory_id': _selectedSubcategoryId,
        if (_selectedSubUnit != null) ...{
          'sub_unit': _selectedSubUnit!.code,
          if (ratio != null && ratio > 0) 'sub_unit_ratio': ratio,
        },
        if (_uploadedImageKey != null) 'image_url': _uploadedImageKey,
        if (description.isNotEmpty) 'description': description,
        'stores': [
          {
            'store_id': widget.storeId,
            'min_quantity': minQty,
            'initial_quantity': initialQty,
            'is_frequent': _newIsFrequent,
          }
        ],
      };

      await ref.read(inventoryServiceProvider).createProduct(data);

      if (!mounted) return;
      await ref.read(inventoryProvider.notifier).loadInventory(widget.storeId);
      await ref.read(inventoryProvider.notifier).loadSummary(widget.storeId);
      ToastManager().success(context, '$name created and added to store');
      context.pop();
    } catch (_) {
      if (!mounted) return;
      ToastManager().error(context, 'Failed to create product');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

class _FormField extends StatelessWidget {
  final String label;
  final Widget child;

  const _FormField({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary),
        ),
        const SizedBox(height: 4),
        child,
      ],
    );
  }
}

class _LabeledNumberField extends StatelessWidget {
  final String label;
  final TextEditingController controller;

  const _LabeledNumberField(
      {required this.label, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(
            contentPadding:
                EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
      ],
    );
  }
}
