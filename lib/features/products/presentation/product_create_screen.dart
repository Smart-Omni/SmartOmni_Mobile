import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/validators.dart';
import '../../../core/widgets/state_views.dart';
import '../domain/product.dart';
import 'products_providers.dart';

/// Tạo sản phẩm mới kèm 1 SKU (POST /api/products).
/// TODO(ui): cho phép thêm nhiều SKU, upload ảnh, dán URL sàn.
class ProductCreateScreen extends ConsumerStatefulWidget {
  const ProductCreateScreen({super.key});

  @override
  ConsumerState<ProductCreateScreen> createState() =>
      _ProductCreateScreenState();
}

class _ProductCreateScreenState extends ConsumerState<ProductCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _desc = TextEditingController();
  final _skuCode = TextEditingController();
  final _variant = TextEditingController();
  final _price = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [_name, _desc, _skuCode, _variant, _price]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(productsRepositoryProvider)
          .createProduct(
            CreateProductInput(
              name: _name.text.trim(),
              description: _desc.text.trim().isEmpty ? null : _desc.text.trim(),
              skus: [
                CreateSkuInput(
                  skuCode: _skuCode.text.trim(),
                  variantName: _variant.text.trim().isEmpty
                      ? null
                      : _variant.text.trim(),
                  basePrice: double.parse(_price.text.trim()),
                ),
              ],
            ),
          );
      ref.invalidate(productsListProvider);
      if (!mounted) return;
      showInfoSnackBar(context, 'Đã tạo sản phẩm');
      context.pop();
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Thêm sản phẩm')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Tên sản phẩm *'),
              validator: (v) => Validators.required(v, field: 'Tên sản phẩm'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _desc,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Mô tả'),
            ),
            const SizedBox(height: 24),
            Text(
              'SKU đầu tiên',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _skuCode,
              decoration: const InputDecoration(labelText: 'Mã SKU *'),
              validator: (v) => Validators.required(v, field: 'Mã SKU'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _variant,
              decoration: const InputDecoration(
                labelText: 'Tên biến thể (vd: Đen / M)',
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _price,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Giá bán (₫) *'),
              validator: (v) => Validators.positiveInt(v, field: 'Giá bán'),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: const Text('Lưu'),
            ),
          ],
        ),
      ),
    );
  }
}
