import 'package:dio/dio.dart';

import '../../../core/models/platform.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/api_paths.dart';
import '../../../core/network/api_response.dart';
import '../../../core/utils/mock_delay.dart';
import '../domain/marketplace_connection.dart';

/// Integration Service, chỉ OAuth (BE `9558375` bỏ kết nối bằng App Key).
/// Công tắc tự nhập: Shopee gọi BE; TikTok BE chưa có API nên chỉ giữ trong
/// phiên chạy app.
class MarketplaceRemoteRepository implements MarketplaceRepository {
  MarketplaceRemoteRepository(this._dio);

  final Dio _dio;
  bool _tiktokAutoImport = false;

  @override
  Future<List<MarketplaceConnection>> listConnections() async {
    try {
      final all = await Future.wait(Platform.values.map(_current));
      return [
        for (final c in all)
          if (c != null)
            c.platform == Platform.tiktokShop
                ? c.copyWith(autoImportProducts: _tiktokAutoImport)
                : c,
      ];
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// Chưa từng kết nối: BE trả `data: null`.
  Future<MarketplaceConnection?> _current(Platform p) async {
    final res = await _dio.get<Object?>(ApiPaths.marketplaceConnection(p));
    return unwrapResponse<MarketplaceConnection?>(
      res.data,
      (data) => data is JsonMap
          ? MarketplaceConnection.fromConnectionDto(data, p)
          : null,
    );
  }

  @override
  Future<OAuthStart> startAuthorization(Platform platform) async {
    try {
      final res = await _dio.post<Object?>(
        ApiPaths.marketplaceAuthorization(platform),
        data: {'redirect_uri': oauthRedirectUri(platform).toString()},
      );
      return unwrapResponse<OAuthStart>(
        res.data,
        (data) => OAuthStart.fromJson(data! as JsonMap),
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  @override
  Future<MarketplaceConnection> completeAuthorization(
    OAuthCallback callback,
  ) async {
    final p = callback.platform;
    try {
      final res = await _dio.post<Object?>(
        ApiPaths.marketplaceCallback(p),
        data: callback.toRequestBody(),
      );
      return unwrapResponse<MarketplaceConnection>(
        res.data,
        (data) => MarketplaceConnection.fromConnectionDto(data! as JsonMap, p),
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  @override
  Future<void> disconnect(Platform platform) async {
    try {
      await _dio.post<Object?>(ApiPaths.marketplaceDisconnect(platform));
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  @override
  Future<void> setAutoImport(Platform platform, {required bool enabled}) async {
    if (platform == Platform.tiktokShop) {
      _tiktokAutoImport = enabled;
      return;
    }
    try {
      await _dio.patch<Object?>(
        ApiPaths.shopeeSettings,
        data: {'auto_import_products': enabled},
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

class MarketplaceMockRepository implements MarketplaceRepository {
  MarketplaceMockRepository({DateTime Function()? clock})
    : _clock = clock ?? DateTime.now {
    final now = _clock();
    _connections.addAll([
      MarketplaceConnection(
        id: 1,
        platform: Platform.shopee,
        status: ConnectionStatus.connected,
        shopId: '123456789',
        shopName: 'Shop Demo Official',
        lastSyncedAt: now.subtract(const Duration(minutes: 5)),
        autoImportProducts: true,
      ),
      MarketplaceConnection(
        id: 2,
        platform: Platform.tiktokShop,
        status: ConnectionStatus.error,
        shopId: '7495120036',
        shopName: 'Shop Demo',
        lastSyncedAt: now.subtract(const Duration(days: 2, hours: 3)),
      ),
    ]);
  }

  final DateTime Function() _clock;
  final List<MarketplaceConnection> _connections = [];

  @override
  Future<List<MarketplaceConnection>> listConnections() async {
    await MockDelay.short();
    return List.unmodifiable(_connections);
  }

  /// `state` của lần bắt đầu gần nhất mỗi sàn (giống BE: dùng một lần).
  final _states = <Platform, String>{};
  var _stateSeq = 0;

  /// Không có trang ủy quyền thật: trả thẳng deep link mà sàn sẽ gọi về khi
  /// người bán đồng ý, nên app không mở trình duyệt.
  @override
  Future<OAuthStart> startAuthorization(Platform platform) async {
    await MockDelay.short();
    final state = 'mock-${++_stateSeq}';
    _states[platform] = state;
    return OAuthStart(
      authorizationUrl: oauthRedirectUri(platform).replace(
        queryParameters: {
          'code': 'mock-code',
          'state': state,
          if (platform == Platform.shopee) 'shop_id': '123456789',
        },
      ),
      expiresAt: _clock().add(const Duration(minutes: 10)),
    );
  }

  @override
  Future<MarketplaceConnection> completeAuthorization(
    OAuthCallback callback,
  ) async {
    await MockDelay.short();
    final platform = callback.platform;
    final prefix = platform == Platform.shopee ? 'SHOPEE' : 'TIKTOK';
    if (callback.state == null || callback.state != _states.remove(platform)) {
      throw ApiException(
        type: ApiErrorType.validation,
        message: 'Authorization state is missing or invalid',
        code: '${prefix}_STATE_INVALID',
      );
    }
    if (callback.denied) {
      throw ApiException(
        type: ApiErrorType.validation,
        message: 'The seller did not authorize SmartOmni',
        code: '${prefix}_AUTHORIZATION_DENIED',
      );
    }
    if (!canConnect(_connections, platform)) {
      throw ApiException(
        type: ApiErrorType.validation,
        message: 'Cửa hàng đã kết nối ${platform.label}. Mỗi sàn chỉ 1 shop.',
      );
    }
    // Kết nối lại (đang lỗi / đã ngắt) thay bản ghi cũ của sàn đó.
    _connections.removeWhere((c) => c.platform == platform);
    final c = MarketplaceConnection(
      id: _connections.length + 10,
      platform: platform,
      status: ConnectionStatus.connected,
      shopId: platform == Platform.shopee ? '123456789' : '7495120036',
      shopName: 'Shop Demo',
      lastSyncedAt: _clock(),
    );
    _connections.add(c);
    return c;
  }

  @override
  Future<void> disconnect(Platform platform) async {
    await MockDelay.short();
    _update(platform, (c) => c.copyWith(status: ConnectionStatus.disconnected));
  }

  @override
  Future<void> setAutoImport(Platform platform, {required bool enabled}) async {
    await MockDelay.short();
    _update(platform, (c) => c.copyWith(autoImportProducts: enabled));
  }

  void _update(
    Platform platform,
    MarketplaceConnection Function(MarketplaceConnection) change,
  ) {
    final i = _connections.indexWhere((c) => c.platform == platform);
    if (i >= 0) _connections[i] = change(_connections[i]);
  }
}
