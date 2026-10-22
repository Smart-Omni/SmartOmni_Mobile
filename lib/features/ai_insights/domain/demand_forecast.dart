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

/// Tổng hợp cho thẻ số liệu M-51.
///
/// [reorder]: số lớn nhất của `recommendedReorderQty` trong các ngày (0 nếu
/// không ngày nào gợi ý). TODO(api): hỏi BE số này là theo từng ngày hay đã
/// lũy kế; nếu theo từng ngày thì phải cộng thay vì lấy lớn nhất.
({int predicted, int reorder}) summarizeForecast(
  Iterable<DemandForecast> days,
) {
  var predicted = 0;
  var reorder = 0;
  for (final d in days) {
    predicted += d.predictedQuantity;
    final r = d.recommendedReorderQty ?? 0;
    if (r > reorder) reorder = r;
  }
  return (predicted: predicted, reorder: reorder);
}
