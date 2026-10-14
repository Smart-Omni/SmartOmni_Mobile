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
    this.autoImportProducts = false,
  });

  final int id;
  final Platform platform;
  final ConnectionStatus status;
  final String? shopId;
  final bool autoImportProducts;

  factory MarketplaceConnection.fromJson(JsonMap json) => MarketplaceConnection(
    id: Json.asInt(json['id']) ?? 0,
    platform: Platform.fromBackend(json['platform'] as String?),
    shopId: Json.asString(json['shopId']),
    autoImportProducts: json['autoImportProducts'] == true,
    status: switch ((json['status'] as String?)?.toUpperCase()) {
      'ERROR' => ConnectionStatus.error,
      'DISCONNECTED' => ConnectionStatus.disconnected,
      _ => ConnectionStatus.connected,
    },
  );
}

abstract class MarketplaceRepository {
  /// ⚠️ Backend CHƯA có API xem danh sách kết nối -> mock.
  Future<List<MarketplaceConnection>> listConnections();

  /// POST /api/marketplace-connections
  /// { platform, appKey, appSecret, autoImportProducts }
  Future<MarketplaceConnection> connect({
    required Platform platform,
    required String appKey,
    required String appSecret,
    bool autoImportProducts = false,
  });
}
