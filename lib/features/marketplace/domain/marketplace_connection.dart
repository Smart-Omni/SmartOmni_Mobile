import '../../../core/models/platform.dart';
import '../../../core/network/api_response.dart';

enum ConnectionStatus { connected, error, disconnected }

/// Kết nối shop trên sàn (entity `marketplace_connections`).
/// Mỗi tenant tối đa 1 shop Shopee + 1 shop TikTok Shop.
class MarketplaceConnection {
  const MarketplaceConnection({
    required this.id,
    required this.platform,
    required this.status,
    this.shopId,
    this.shopName,
    this.lastSyncedAt,
    this.autoImportProducts = false,
  });

  final int id;
  final Platform platform;
  final ConnectionStatus status;
  final String? shopId;
  final String? shopName;
  final DateTime? lastSyncedAt;

  /// Tự nhập sản phẩm & đơn từ shop.
  final bool autoImportProducts;

  MarketplaceConnection copyWith({
    ConnectionStatus? status,
    bool? autoImportProducts,
  }) => MarketplaceConnection(
    id: id,
    platform: platform,
    status: status ?? this.status,
    shopId: shopId,
    shopName: shopName,
    lastSyncedAt: lastSyncedAt,
    autoImportProducts: autoImportProducts ?? this.autoImportProducts,
  );

  /// `ShopeeConnectionDto` / `TiktokConnectionDto` của BE (camelCase).
  /// `MISSING_SCOPE`, `REFRESH_FAILED`, `REVOKED` (`needsReconnect`) = lỗi kết
  /// nối. DTO không có giờ đồng bộ và `autoImportProducts`.
  factory MarketplaceConnection.fromConnectionDto(
    JsonMap json,
    Platform platform,
  ) {
    final status = (json['status'] as String?)?.toUpperCase();
    return MarketplaceConnection(
      id: Json.asInt(json['id']) ?? 0,
      platform: platform,
      shopId: Json.asString(json['shopId']),
      shopName: Json.asString(json['shopName']),
      status: status == 'CONNECTED' && json['needsReconnect'] != true
          ? ConnectionStatus.connected
          : status == 'DISCONNECTED'
          ? ConnectionStatus.disconnected
          : ConnectionStatus.error,
    );
  }

  factory MarketplaceConnection.fromJson(JsonMap json) => MarketplaceConnection(
    id: Json.asInt(json['id']) ?? 0,
    platform: Platform.fromBackend(json['platform'] as String?),
    shopId: Json.asString(json['shopId']),
    shopName: Json.asString(json['shopName']),
    lastSyncedAt: Json.asDate(json['lastSyncedAt']),
    autoImportProducts: json['autoImportProducts'] == true,
    status: switch ((json['status'] as String?)?.toUpperCase()) {
      'ERROR' => ConnectionStatus.error,
      'DISCONNECTED' => ConnectionStatus.disconnected,
      _ => ConnectionStatus.connected,
    },
  );
}

/// Kết nối của [platform] trong danh sách, `null` nếu chưa có.
MarketplaceConnection? connectionFor(
  Iterable<MarketplaceConnection> connections,
  Platform platform,
) => connections.where((c) => c.platform == platform).firstOrNull;

/// Được kết nối (hoặc kết nối lại) [platform] khi sàn đó chưa có kết nối
/// đang chạy: chưa từng kết nối, đang lỗi hoặc đã ngắt. Mỗi sàn chỉ 1 shop.
bool canConnect(
  Iterable<MarketplaceConnection> connections,
  Platform platform,
) => connectionFor(connections, platform)?.status != ConnectionStatus.connected;

abstract class MarketplaceRepository {
  /// GET /api/v1/marketplace-connections/{shopee,tiktok-shop}
  Future<List<MarketplaceConnection>> listConnections();

  /// POST /api/v1/marketplace-connections. BE hiện luôn trả 400 cho cả hai
  /// sàn (bắt dùng OAuth): T-10 chỉ mở form này ở chế độ mock.
  /// { platform, appKey, appSecret, autoImportProducts }
  Future<MarketplaceConnection> connect({
    required Platform platform,
    required String appKey,
    required String appSecret,
    bool autoImportProducts = false,
  });

  /// ⚠️ Backend CHƯA có API ngắt kết nối -> mock.
  Future<void> disconnect(Platform platform);

  /// ⚠️ Backend CHƯA có API đổi "tự nhập sản phẩm & đơn" -> mock.
  Future<void> setAutoImport(Platform platform, {required bool enabled});
}
