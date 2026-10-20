import 'package:dio/dio.dart';

import '../../../core/models/platform.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/api_response.dart';
import '../../../core/utils/mock_delay.dart';
import '../domain/marketplace_connection.dart';

class MarketplaceRemoteRepository implements MarketplaceRepository {
  MarketplaceRemoteRepository(this._dio, this._fallback);

  final Dio _dio;
  final MarketplaceRepository _fallback;

  @override
  Future<List<MarketplaceConnection>> listConnections() =>
      _fallback.listConnections();

  @override
  Future<MarketplaceConnection> connect({
    required Platform platform,
    required String appKey,
    required String appSecret,
    bool autoImportProducts = false,
  }) async {
    try {
      final res = await _dio.post<Object?>(
        '/api/marketplace-connections',
        data: {
          'platform': platform.backendValue,
          'appKey': appKey,
          'appSecret': appSecret,
          'autoImportProducts': autoImportProducts,
        },
      );
      return unwrapResponse<MarketplaceConnection>(
        res.data,
        (data) => MarketplaceConnection.fromJson(data! as JsonMap),
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  @override
  Future<void> disconnect(Platform platform) => _fallback.disconnect(platform);

  @override
  Future<void> setAutoImport(Platform platform, {required bool enabled}) =>
      _fallback.setAutoImport(platform, enabled: enabled);
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

  @override
  Future<MarketplaceConnection> connect({
    required Platform platform,
    required String appKey,
    required String appSecret,
    bool autoImportProducts = false,
  }) async {
    await MockDelay.short();
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
      autoImportProducts: autoImportProducts,
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
