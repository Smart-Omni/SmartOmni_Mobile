import 'package:flutter_test/flutter_test.dart';
import 'package:smartomni_mobile/core/models/platform.dart';
import 'package:smartomni_mobile/features/inventory/domain/inventory_item.dart';
import 'package:smartomni_mobile/features/orders/domain/order.dart';
import 'package:smartomni_mobile/features/products/domain/product.dart';

void main() {
  group('Order.fromJson', () {
    test('parse đơn từ JSON backend', () {
      final order = Order.fromJson({
        'id': 10,
        'tenantId': 1,
        'platform': 'TIKTOK_SHOP',
        'platformOrderId': '5779',
        'status': 'TO_SHIP',
        'totalAmount': 318000.00,
        'customerName': 'A',
        'source': 'POLLING',
        'createdAt': '2026-10-14T03:00:00Z',
      });
      expect(order.id, 10);
      expect(order.platform, Platform.tiktokShop);
      expect(order.status, OrderStatus.toShip);
      expect(order.totalAmount, 318000);
      expect(order.source, OrderSource.polling);
      expect(order.createdAt, isNotNull);
    });
  });

  group('OrderStatus.manualTransitions', () {
    test('chỉ PENDING được chuyển tay sang TO_SHIP', () {
      expect(OrderStatus.pending.manualTransitions, [OrderStatus.toShip]);
    });

    test('không được chỉnh tay hoàn tất / trả hàng / hủy', () {
      for (final s in OrderStatus.values.where(
        (s) => s != OrderStatus.pending,
      )) {
        expect(s.manualTransitions, isEmpty, reason: s.name);
      }
      for (final s in OrderStatus.values) {
        expect(s.manualTransitions, isNot(contains(OrderStatus.completed)));
        expect(s.manualTransitions, isNot(contains(OrderStatus.returned)));
      }
    });
  });

  group('Product', () {
    test('minPrice lấy giá thấp nhất trong SKU', () {
      const p = Product(
        id: 1,
        name: 'X',
        skus: [
          Sku(id: 1, skuCode: 'A', basePrice: 200),
          Sku(id: 2, skuCode: 'B', basePrice: 150),
        ],
      );
      expect(p.minPrice, 150);
      expect(const Product(id: 2, name: 'Y').minPrice, isNull);
    });

    test('CreateProductInput.toJson khớp CreateProductRequest', () {
      const input = CreateProductInput(
        name: 'Áo',
        skus: [CreateSkuInput(skuCode: 'A1', basePrice: 100000)],
      );
      expect(input.toJson(), {
        'name': 'Áo',
        'skus': [
          {'skuCode': 'A1', 'basePrice': 100000.0},
        ],
      });
    });
  });

  group('InventoryItem', () {
    test('tính có thể bán và cảnh báo sắp hết', () {
      const item = InventoryItem(
        skuId: 1,
        skuCode: 'A',
        productName: 'X',
        quantityOnHand: 7,
        reservedQuantity: 3,
      );
      expect(item.available, 4);
      expect(item.isLow, isTrue);
      expect(item.copyWith(quantityOnHand: 3).isOutOfStock, isTrue);
      expect(item.copyWith(quantityOnHand: 50).isLow, isFalse);
    });
  });
}
