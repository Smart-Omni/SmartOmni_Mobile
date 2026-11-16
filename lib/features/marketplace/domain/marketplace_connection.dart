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
  /// nối. DTO không có giờ đồng bộ; `autoImportProducts` chỉ Shopee có.
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
      autoImportProducts: json['autoImportProducts'] == true,
      status: status == 'CONNECTED' && json['needsReconnect'] != true
          ? ConnectionStatus.connected
          : status == 'DISCONNECTED'
          ? ConnectionStatus.disconnected
          : ConnectionStatus.error,
    );
  }
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

/// Kết quả `POST …/authorization` (`ShopeeAuthorizationStartDto` /
/// `TiktokAuthorizationStartDto`): trang ủy quyền của sàn và lúc `state` hết
/// hạn.
class OAuthStart {
  const OAuthStart({required this.authorizationUrl, this.expiresAt});

  factory OAuthStart.fromJson(JsonMap json) => OAuthStart(
    authorizationUrl: Uri.parse(json['authorizationUrl'] as String),
    expiresAt: Json.asDate(json['expiresAt']),
  );

  final Uri authorizationUrl;
  final DateTime? expiresAt;
}

/// Địa chỉ sàn chuyển về app sau khi người bán ủy quyền. BE Shopee nhận mọi
/// `smartomni://…`; BE TikTok chỉ nhận địa chỉ có trong
/// `TIKTOK_ALLOWED_REDIRECT_URIS`.
const oauthScheme = 'smartomni';
const oauthHost = 'oauth';

Uri oauthRedirectUri(Platform p) => Uri(
  scheme: oauthScheme,
  host: oauthHost,
  path: switch (p) {
    Platform.shopee => '/shopee',
    Platform.tiktokShop => '/tiktok',
  },
);

/// Tham số sàn gắn vào deep link `smartomni://oauth/<shopee|tiktok>`:
/// thành công `?code=&state=(&shop_id=)`, từ chối `?error=&state=`.
class OAuthCallback {
  const OAuthCallback({
    required this.platform,
    this.code,
    this.state,
    this.shopId,
    this.error,
    this.errorDescription,
  });

  final Platform platform;
  final String? code;
  final String? state;

  /// Chỉ Shopee gửi.
  final String? shopId;
  final String? error;
  final String? errorDescription;

  /// Người bán bấm từ chối trên trang của sàn.
  bool get denied => error != null && error!.isNotEmpty;

  /// `null` nếu [uri] không phải deep link OAuth của app.
  static OAuthCallback? tryParse(Uri uri) {
    if (uri.scheme != oauthScheme || uri.host != oauthHost) return null;
    final platform = Platform.values
        .where((p) => oauthRedirectUri(p).path == uri.path)
        .firstOrNull;
    if (platform == null) return null;
    String? q(String key) {
      final v = uri.queryParameters[key]?.trim();
      return v == null || v.isEmpty ? null : v;
    }

    return OAuthCallback(
      platform: platform,
      code: q('code'),
      state: q('state'),
      shopId: q('shop_id'),
      error: q('error'),
      errorDescription: q('error_description'),
    );
  }

  /// Body `POST …/callback`: Shopee snake_case (`ShopeeCallbackRequest`),
  /// TikTok camelCase (`TiktokCallbackRequest`).
  Map<String, Object?> toRequestBody() => switch (platform) {
    Platform.shopee => {
      'code': code,
      'shop_id': shopId,
      'state': state,
      'error': error,
      'error_description': errorDescription,
    },
    Platform.tiktokShop => {
      'code': code,
      'state': state,
      'error': error,
      'errorDescription': errorDescription,
    },
  };
}

abstract class MarketplaceRepository {
  /// GET /api/v1/marketplace-connections/{shopee,tiktok-shop}
  Future<List<MarketplaceConnection>> listConnections();

  /// POST {base}/authorization `{ redirect_uri }`: bắt đầu OAuth. BE ràng
  /// `state` với tenant và user đang đăng nhập.
  Future<OAuthStart> startAuthorization(Platform platform);

  /// POST {base}/callback: gửi tham số deep link, phải dùng JWT của user đã
  /// bắt đầu OAuth. Trả kết nối mới.
  Future<MarketplaceConnection> completeAuthorization(OAuthCallback callback);

  /// POST {base}/disconnect
  Future<void> disconnect(Platform platform);

  /// Shopee: PATCH {base}/settings `{ auto_import_products }`. TikTok: BE
  /// chưa có API, chỉ giữ trong phiên chạy app.
  Future<void> setAutoImport(Platform platform, {required bool enabled});
}
