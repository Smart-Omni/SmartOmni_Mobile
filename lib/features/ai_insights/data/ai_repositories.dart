import 'package:dio/dio.dart';

import '../../../core/mock/mock_data.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/api_paths.dart';
import '../../../core/network/api_response.dart';
import '../../../core/utils/mock_delay.dart';
import '../domain/demand_forecast.dart';

class AiRemoteRepository implements AiRepository {
  AiRemoteRepository(this._dio);

  final Dio _dio;

  @override
  Future<List<DemandForecast>> forecastForSku(int skuId) async {
    try {
      final res = await _dio.get<Object?>(ApiPaths.forecast(skuId));
      return unwrapResponse<List<DemandForecast>>(
        res.data,
        (data) => [
          for (final e in (data as List<dynamic>? ?? const []))
            ?DemandForecast.tryFromJson(e as JsonMap),
        ],
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

class AiMockRepository implements AiRepository {
  AiMockRepository({DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;

  @override
  Future<List<DemandForecast>> forecastForSku(int skuId) async {
    await MockDelay.short();
    final stock = MockData.inventory[skuId]?.$1 ?? 10;
    return [
      for (var d = 1; d <= 7; d++)
        DemandForecast(
          forecastDate: _clock().add(Duration(days: d)),
          predictedQuantity: 2 + (skuId + d) % 5,
          recommendedReorderQty: stock < 10 && d == 1 ? 30 : null,
        ),
    ];
  }
}
