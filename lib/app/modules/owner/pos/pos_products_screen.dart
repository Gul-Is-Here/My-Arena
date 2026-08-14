import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../controllers/pos_controller.dart';
import '../../../data/models/pos_product_model.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';

class PosProductsScreen extends StatelessWidget {
  const PosProductsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<PosController>()) {
      Get.put(PosController(), permanent: true);
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: const Text('Products & Add-ons'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        icon: const Icon(Icons.add),
        label: const Text('Add Product'),
        onPressed: () => _showProductSheet(context),
      ),
      body: Obx(() {
        final products = PosController.to.products;
        if (products.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inventory_2_outlined, color: AppColors.textDisabled, size: 48),
                SizedBox(height: 12),
                Text('No products yet', style: TextStyle(color: AppColors.textSecondary)),
                SizedBox(height: 4),
                Text('Add equipment, beverages, coaching, etc.',
                    style: TextStyle(color: AppColors.textDisabled, fontSize: 12)),
              ],
            ),
          );
        }

        final byCategory = <ProductCategory, List<PosProductModel>>{};
        for (final p in products) {
          byCategory.putIfAbsent(p.category, () => []).add(p);
        }

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
          children: byCategory.entries.map((entry) => _CategorySection(
            category: entry.key,
            products: entry.value,
          )).toList(),
        );
      }),
    );
  }

  void _showProductSheet(BuildContext context, [PosProductModel? existing]) {
    Get.bottomSheet(
      isScrollControlled: true,
      _ProductSheet(existing: existing),
    );
  }
}

class _CategorySection extends StatelessWidget {
  final ProductCategory category;
  final List<PosProductModel> products;
  const _CategorySection({required this.category, required this.products});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Text(category.label, style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textSecondary, fontWeight: FontWeight.w700,
            letterSpacing: 0.4)),
        ),
        ...products.map((p) => _ProductCard(product: p)),
        const SizedBox(height: 6),
      ],
    );
  }
}

class _ProductCard extends StatelessWidget {
  final PosProductModel product;
  const _ProductCard({required this.product});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.inventory_2_outlined, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(product.name, style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                    const SizedBox(width: 8),
                    if (!product.isActive)
                      _badge('Inactive', AppColors.textDisabled),
                  ],
                ),
                if (product.description.isNotEmpty)
                  Text(product.description, style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('PKR ${product.price.toStringAsFixed(0)}',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.primary, fontWeight: FontWeight.w800)),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 16, color: AppColors.textSecondary),
                    onPressed: () => Get.bottomSheet(
                      isScrollControlled: true, _ProductSheet(existing: product)),
                    padding: EdgeInsets.zero, constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 16, color: AppColors.error),
                    onPressed: () => _confirmDelete(product.id),
                    padding: EdgeInsets.zero, constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _badge(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(text, style: AppTextStyles.caption.copyWith(
          color: color, fontSize: 10, fontWeight: FontWeight.w600)),
      );

  void _confirmDelete(String id) {
    Get.dialog(AlertDialog(
      backgroundColor: AppColors.surface,
      title: const Text('Delete Product?', style: TextStyle(color: AppColors.textPrimary)),
      content: const Text('This action cannot be undone.',
          style: TextStyle(color: AppColors.textSecondary)),
      actions: [
        TextButton(onPressed: Get.back, child: const Text('Cancel')),
        TextButton(
          onPressed: () {
            PosController.to.deleteProduct(id);
            Get.back();
          },
          child: const Text('Delete', style: TextStyle(color: AppColors.error)),
        ),
      ],
    ));
  }
}

class _ProductSheet extends StatefulWidget {
  final PosProductModel? existing;
  const _ProductSheet({this.existing});

  @override
  State<_ProductSheet> createState() => _ProductSheetState();
}

class _ProductSheetState extends State<_ProductSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _descCtrl;
  ProductCategory _category = ProductCategory.equipment;
  bool _active = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameCtrl = TextEditingController(text: e?.name ?? '');
    _priceCtrl = TextEditingController(text: e != null ? e.price.toStringAsFixed(0) : '');
    _descCtrl = TextEditingController(text: e?.description ?? '');
    if (e != null) {
      _category = e.category;
      _active = e.isActive;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final price = double.tryParse(_priceCtrl.text);
    if (name.isEmpty || price == null || price <= 0) {
      Get.snackbar('Error', 'Name and price are required',
          backgroundColor: AppColors.error, colorText: Colors.white);
      return;
    }

    setState(() => _saving = true);
    try {
      final pos = PosController.to;
      final arena = pos.selectedArena.value;
      if (arena == null) return;

      final product = PosProductModel(
        id: widget.existing?.id ?? '',
        arenaId: arena.id,
        name: name,
        category: _category,
        price: price,
        description: _descCtrl.text.trim(),
        isActive: _active,
        createdAt: widget.existing?.createdAt ?? DateTime.now(),
      );

      if (widget.existing != null) {
        await pos.updateProduct(product);
      } else {
        await pos.addProduct(product);
      }
      Get.back();
    } catch (e) {
      Get.snackbar('Error', e.toString(),
          backgroundColor: AppColors.error, colorText: Colors.white);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;

    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 16, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
            )),
            const SizedBox(height: 16),
            Text(isEdit ? 'Edit Product' : 'Add Product',
                style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),

            // Category
            Text('Category', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: ProductCategory.values.map((c) {
                final sel = _category == c;
                return GestureDetector(
                  onTap: () => setState(() => _category = c),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: sel ? AppColors.primary.withValues(alpha: 0.12) : AppColors.elevated,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: sel ? AppColors.primary : AppColors.border),
                    ),
                    child: Text(c.label, style: AppTextStyles.caption.copyWith(
                      color: sel ? AppColors.primary : AppColors.textPrimary,
                      fontWeight: sel ? FontWeight.w700 : FontWeight.w400,
                    )),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),

            Text('Product Name', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: 6),
            _field(_nameCtrl, 'e.g. Racket Rental', TextInputType.text, []),
            const SizedBox(height: 14),

            Text('Price (PKR)', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: 6),
            _field(_priceCtrl, 'e.g. 150', TextInputType.number, [FilteringTextInputFormatter.digitsOnly]),
            const SizedBox(height: 14),

            Text('Description (optional)', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: 6),
            _field(_descCtrl, 'e.g. Includes grip tape', TextInputType.text, []),
            const SizedBox(height: 14),

            Row(
              children: [
                Text('Active', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary)),
                const Spacer(),
                Switch(
                  value: _active,
                  onChanged: (v) => setState(() => _active = v),
                  activeColor: AppColors.primary,
                ),
              ],
            ),
            const SizedBox(height: 20),

            FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _saving
                  ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.onPrimary))
                  : Text(isEdit ? 'Save Changes' : 'Add Product'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String hint, TextInputType type,
      List<TextInputFormatter> formatters) =>
      TextField(
        controller: ctrl,
        keyboardType: type,
        inputFormatters: formatters,
        style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.textDisabled),
          filled: true,
          fillColor: AppColors.elevated,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.border)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.border)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primary)),
        ),
      );
}
