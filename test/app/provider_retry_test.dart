import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartomni_mobile/core/design/design.dart';
import 'package:smartomni_mobile/features/products/data/products_repositories.dart';
import 'package:smartomni_mobile/features/products/domain/product.dart';
import 'package:smartomni_mobile/features/products/presentation/products_providers.dart';

import '../helpers/test_app.dart';

/// Danh sách bình thường, chi tiết sản phẩm luôn lỗi.
class _DetailFails extends ProductsMockRepository {
  var detailCalls = 0;

  @override
  Future<Product> getProduct(int id) async {
    detailCalls++;
    throw Exception('mất mạng');
  }
}

void main() {
  // Mặc định Riverpod 3 tự thử lại provider lỗi ~38 giây (màn vẫn skeleton).
  // App tắt việc này ở ProviderScope: lỗi hiện ngay, gọi đúng một lần.
  testWidgets('màn cũ (M-31) hiện lỗi ngay, không tự thử lại', (tester) async {
    final repo = _DetailFails();
    await loginAs(
      tester,
      'staff@demo.vn',
      tallView: true,
      overrides: [productsRepositoryProvider.overrideWithValue(repo)],
    );
    await tester.tap(find.byKey(const Key('nav_products')));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.byKey(const Key('product_1')));

    expect(find.text('Không tải được sản phẩm'), findsOneWidget);
    expect(find.byType(SoSkeleton), findsNothing);
    await tester.pump(const Duration(seconds: 10));
    expect(repo.detailCalls, 1);
  });
}
