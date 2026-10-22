import '../../../core/models/platform.dart';
import '../../../core/utils/mock_delay.dart';
import '../../loyalty/domain/loyalty_rules.dart';
import '../domain/voucher.dart';

/// 128 khách mẫu (Diamond 4 · Platinum 11 · Silver 27 · Standard 86), Shopee
/// tạo được voucher, TikTok Shop thì không. Đợt phát trong phiên chạy app
/// chuyển "Đang tạo" -> "Thành công" sau [confirmAfter].
class VoucherMockRepository implements VoucherRepository {
  VoucherMockRepository({required DateTime Function() clock}) : _clock = clock {
    final now = _clock();
    _batches.addAll([
      VoucherBatch(
        id: 4,
        platform: Platform.shopee,
        discount: 20000,
        minOrder: 150000,
        expiresAt: voucherExpiry(now, 7),
        audience: 'Platinum+',
        customerCount: 15,
        status: VoucherBatchStatus.creating,
        createdAt: now.subtract(const Duration(minutes: 2)),
      ),
      VoucherBatch(
        id: 3,
        platform: Platform.shopee,
        discount: 30000,
        minOrder: 200000,
        expiresAt: voucherExpiry(now, 12),
        audience: 'Silver+',
        customerCount: 42,
        status: VoucherBatchStatus.success,
        createdAt: now.subtract(const Duration(days: 2)),
      ),
      VoucherBatch(
        id: 2,
        platform: Platform.shopee,
        discount: 50000,
        minOrder: 400000,
        expiresAt: voucherExpiry(now, 3),
        audience: 'Diamond',
        customerCount: 4,
        status: VoucherBatchStatus.unknown,
        createdAt: now.subtract(const Duration(days: 4)),
      ),
      VoucherBatch(
        id: 1,
        platform: Platform.shopee,
        discount: 15000,
        minOrder: 100000,
        expiresAt: voucherExpiry(now, -1),
        audience: 'Tất cả',
        customerCount: 128,
        status: VoucherBatchStatus.failed,
        createdAt: now.subtract(const Duration(days: 9)),
        failureReason: 'Shopee từ chối: vượt số voucher trong tháng',
      ),
    ]);
  }

  static const confirmAfter = Duration(seconds: 3);

  final DateTime Function() _clock;
  final _batches = <VoucherBatch>[];

  /// Đợt phát trong phiên này (id -> lúc gửi), để tự chuyển sang thành công.
  final _issuedAt = <int, DateTime>{};

  static final customers = List<VoucherCustomer>.unmodifiable([
    for (var id = 1; id <= 128; id++)
      VoucherCustomer(
        id: id,
        name: '${_family[id % _family.length]} ${_given[id % _given.length]}',
        email: 'khach$id@demo.vn',
        tier: id <= 4
            ? LoyaltyTier.diamond
            : id <= 15
            ? LoyaltyTier.platinum
            : id <= 42
            ? LoyaltyTier.silver
            : LoyaltyTier.standard,
      ),
  ]);

  static const _family = [
    'Nguyễn',
    'Trần',
    'Lê',
    'Phạm',
    'Hoàng',
    'Võ',
    'Đặng',
  ];
  static const _given = [
    'An',
    'Bình',
    'Chi',
    'Dũng',
    'Giang',
    'Hà',
    'Khánh',
    'Linh',
    'Minh',
    'Ngọc',
    'Phúc',
  ];

  @override
  Future<VoucherSetup> setup() async {
    await MockDelay.short();
    return VoucherSetup(
      customers: customers,
      support: const {
        Platform.shopee: VoucherSupport.available,
        Platform.tiktokShop: VoucherSupport.unsupported,
      },
    );
  }

  @override
  Future<List<VoucherBatch>> recentBatches() async {
    await MockDelay.short();
    final now = _clock();
    for (final (i, b) in _batches.indexed) {
      final sent = _issuedAt[b.id];
      if (b.status == VoucherBatchStatus.creating &&
          sent != null &&
          now.difference(sent) >= confirmAfter) {
        _batches[i] = b.copyWith(status: VoucherBatchStatus.success);
      }
    }
    return List.unmodifiable(_batches);
  }

  @override
  Future<VoucherBatch> issue(VoucherDraft draft) async {
    await MockDelay.short();
    final now = _clock();
    final batch = VoucherBatch(
      id: _batches.fold(0, (max, b) => b.id > max ? b.id : max) + 1,
      platform: draft.platform,
      discount: draft.discount,
      minOrder: draft.minOrder,
      expiresAt: draft.expiresAt,
      audience: draft.audience,
      customerCount: draft.customerIds.length,
      status: VoucherBatchStatus.creating,
      createdAt: now,
    );
    _batches.insert(0, batch);
    _issuedAt[batch.id] = now;
    return batch;
  }
}
