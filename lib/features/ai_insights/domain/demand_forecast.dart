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

  /// Entity `DemandForecast` của BE (camelCase, `forecastDate` dạng
  /// "2026-11-12"). Không đọc được ngày thì trả `null` (bỏ dòng đó).
  static DemandForecast? tryFromJson(JsonMap json) {
    final date = Json.asDate(json['forecastDate']);
    if (date == null) return null;
    return DemandForecast(
      forecastDate: date,
      predictedQuantity: Json.asInt(json['predictedQuantity']) ?? 0,
      recommendedReorderQty: Json.asInt(json['recommendedReorderQty']),
    );
  }
}

abstract class AiRepository {
  /// GET /api/v1/ai/forecast/{skuId}. BE trả mọi dòng của SKU, không sắp xếp
  /// (có thể gồm ngày đã qua): lọc bằng [upcomingForecast].
  Future<List<DemandForecast>> forecastForSku(int skuId);
}

/// Số ngày M-51 hiển thị.
const forecastDays = 7;

/// Dự báo từ [today] trở đi, sắp xếp theo ngày, tối đa [forecastDays] ngày.
List<DemandForecast> upcomingForecast(
  Iterable<DemandForecast> days,
  DateTime today,
) {
  final start = DateTime(today.year, today.month, today.day);
  return ([...days.where((d) => !d.forecastDate.isBefore(start))]
        ..sort((a, b) => a.forecastDate.compareTo(b.forecastDate)))
      .take(forecastDays)
      .toList();
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
