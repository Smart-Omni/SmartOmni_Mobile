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
}

class MarketplaceMockRepository implements MarketplaceRepository {
  final List<MarketplaceConnection> _connections = [
    const MarketplaceConnection(
      id: 1,
      platform: Platform.shopee,
      status: ConnectionStatus.connected,
      shopId: '123456789',
      autoImportProducts: true,
    ),
  ];

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
    if (_connections.any((c) => c.platform == platform)) {
      throw ApiException(
        type: ApiErrorType.validation,
        message: 'Cửa hàng đã kết nối ${platform.label}. Mỗi sàn chỉ 1 shop.',
      );
    }
    final c = MarketplaceConnection(
      id: _connections.length + 1,
      platform: platform,
      status: ConnectionStatus.connected,
      shopId: 'mock-${platform.name}',
      autoImportProducts: autoImportProducts,
    );
    _connections.add(c);
    return c;
  }
}
