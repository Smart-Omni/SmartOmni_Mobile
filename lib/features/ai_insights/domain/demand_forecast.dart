import '../../../core/network/api_response.dart';

/// Dự báo nhu cầu theo ngày cho 1 SKU (entity `demand_forecasts`).
class DemandForecast {
  const DemandForecast({
    required this.forecastDate,
    required this.predictedQuantity,
    this.recommendedReorderQty,
  });

  final DateTime forecastDate;
  final int predictedQuantity;
  final int? recommendedReorderQty;

  factory DemandForecast.fromJson(JsonMap json) => DemandForecast(
    forecastDate: Json.asDate(json['forecastDate']) ?? DateTime.now(),
    predictedQuantity: Json.asInt(json['predictedQuantity']) ?? 0,
    recommendedReorderQty: Json.asInt(json['recommendedReorderQty']),
  );
}

abstract class AiRepository {
  /// GET /api/ai/forecast/{skuId}
  Future<List<DemandForecast>> forecastForSku(int skuId);
}
