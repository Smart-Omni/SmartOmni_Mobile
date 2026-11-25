import 'package:dio/dio.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/api_paths.dart';
import '../../../core/network/api_response.dart';
import '../domain/subscription.dart';

/// Đọc JSON của `/api/v1/tenants/subscription/*` (BE `develop` @ `f9495df`,
/// tenant-service, `dto/Subscription*`). camelCase như DTO Java; `LocalDate`
/// là chuỗi `yyyy-MM-dd`, `Instant` là chuỗi ISO-8601, `BigDecimal` là số.
abstract final class SubscriptionJson {
  /// `SubscriptionSummaryResponse`: `{ planName, isPro, status, periodStart,
  /// periodEnd, daysRemaining, canRenewEarly, currentInvoiceId }`.
  ///
  /// `isPro` là `boolean` có getter Lombok `isPro()` nên Jackson ghi thành
  /// `"pro"`. Đọc cả `"pro"` lẫn `"isPro"` (phòng BE thêm `@JsonProperty`).
  static SubscriptionSummary summary(Object? data) {
    final map = data is JsonMap ? data : const <String, dynamic>{};
    final status = PlanStatus.fromBackend(map['status']);
    final days = Json.asInt(map['daysRemaining']) ?? 0;
    final name = Json.asString(map['planName'])?.trim();
    return SubscriptionSummary(
      planName: name == null || name.isEmpty ? 'FREE' : name,
      isPro: (map['pro'] ?? map['isPro']) == true,
      status: status,
      periodStart: Json.asDate(map['periodStart']),
      periodEnd: Json.asDate(map['periodEnd']),
      daysRemaining: days < 0 ? 0 : days,
      canRenewEarly: map['canRenewEarly'] == true,
      currentInvoiceId: Json.asInt(map['currentInvoiceId']),
    );
  }

  /// `SubscriptionInvoiceDto`: `{ id, invoiceNumber, paymentCode,
  /// gatewayTransactionId, paymentMethod, period, amount, status, dueDate,
  /// paidAt, createdAt }`. `period` là chuỗi `"yyyy-MM-dd - yyyy-MM-dd"`.
  static Invoice invoice(JsonMap json) {
    final number = Json.asString(json['invoiceNumber'])?.trim();
    final id = Json.asInt(json['id']);
    final (start, end) = _period(json['period']);
    return Invoice(
      code: number != null && number.isNotEmpty
          ? number
          : (id == null ? 'Hóa đơn' : 'INV-$id'),
      amount: Json.asDouble(json['amount']) ?? 0,
      paid: Json.asString(json['status'])?.trim().toUpperCase() == 'PAID',
      periodStart: start,
      periodEnd: end,
      dueDate: Json.asDate(json['dueDate']),
      paidAt: Json.asDate(json['paidAt']),
      paymentMethod: Json.asString(json['paymentMethod']),
    );
  }

  static List<Invoice> invoices(Object? data) => [
    for (final e in (data is List ? data : const []))
      if (e is JsonMap) invoice(e),
  ];

  /// `SubscriptionCheckoutResponse`: `{ orderCode, amount, qrUrl,
  /// accountNumber, bankId, accountHolder, memo, planName, expiresAt }`.
  /// Thiếu `orderCode` thì không hỏi trạng thái được: báo lỗi.
  static CheckoutSession checkout(Object? data, {required DateTime now}) {
    final map = data is JsonMap ? data : const <String, dynamic>{};
    final code = Json.asString(map['orderCode'])?.trim() ?? '';
    if (code.isEmpty) {
      throw const ApiException(
        type: ApiErrorType.unknown,
        message: 'Máy chủ không trả mã thanh toán. Vui lòng thử lại.',
      );
    }
    String text(String key) => Json.asString(map[key])?.trim() ?? '';
    final memo = text('memo');
    return CheckoutSession(
      orderCode: code,
      amount: Json.asDouble(map['amount']) ?? 0,
      qrUrl: text('qrUrl'),
      accountNumber: text('accountNumber'),
      bankId: text('bankId'),
      accountHolder: text('accountHolder'),
      memo: memo.isEmpty ? code : memo,
      planName: text('planName').isEmpty ? 'PRO' : text('planName'),
      // BE luôn gửi; thiếu thì lấy đúng thời hạn BE dùng (15 phút).
      expiresAt:
          Json.asDate(map['expiresAt']) ?? now.add(const Duration(minutes: 15)),
    );
  }

  /// `SubscriptionOrderStatusResponse`: `{ orderCode, status, planName,
  /// paidAt }`.
  static PaymentStatus orderStatus(Object? data) =>
      PaymentStatus.fromBackend(data is JsonMap ? data['status'] : null);

  static (DateTime?, DateTime?) _period(Object? value) {
    final parts = (value?.toString() ?? '').split(' - ');
    if (parts.length != 2) return (null, null);
    return (Json.asDate(parts[0].trim()), Json.asDate(parts[1].trim()));
  }
}

/// T-40 gọi `/api/v1/tenants/subscription/*`. BE lấy tenant từ JWT. Hạn mức
/// và mức đã dùng chưa có API (lỗi P3) nên lấy từ [usage] (mock).
class SubscriptionRemoteRepository implements SubscriptionRepository {
  SubscriptionRemoteRepository(
    this._dio, {
    required SubscriptionRepository usage,
    required DateTime Function() clock,
  }) : _usage = usage,
       _clock = clock;

  final Dio _dio;
  final SubscriptionRepository _usage;
  final DateTime Function() _clock;

  @override
  Future<SubscriptionSummary> status() => _send(
    () => _dio.get<Object?>(ApiPaths.subscriptionStatus),
    SubscriptionJson.summary,
  );

  @override
  Future<List<Invoice>> invoices() => _send(
    () => _dio.get<Object?>(ApiPaths.subscriptionInvoices),
    SubscriptionJson.invoices,
  );

  @override
  Future<PlanUsage> usage() => _usage.usage();

  @override
  Future<CheckoutSession> checkout() => _send(
    () => _dio.post<Object?>(ApiPaths.subscriptionCheckout),
    (d) => SubscriptionJson.checkout(d, now: _clock()),
  );

  @override
  Future<PaymentStatus> orderStatus(String orderCode) => _send(
    () => _dio.get<Object?>(ApiPaths.subscriptionOrderStatus(orderCode)),
    SubscriptionJson.orderStatus,
  );

  /// Giả lập SePay báo đã nhận tiền. **Chỉ bản dev gọi** (nút trong sheet chỉ
  /// có khi `AppConfig.allowsPaymentSimulation`).
  ///
  /// Lỗi P1 (docs/API_CONTRACT.md): BE `f9495df` mở API này cho mọi user đã
  /// đăng nhập, ở mọi môi trường, nên ai cũng tự lên PRO được mà không trả
  /// tiền. App không được dựa vào API này: luồng thật chỉ chờ webhook SePay
  /// và hỏi `/orders/{code}/status`.
  @override
  Future<void> simulatePay(String orderCode) => _send(
    () => _dio.post<Object?>(ApiPaths.subscriptionSimulatePay(orderCode)),
    (d) {
      if (d == false) {
        throw const ApiException(
          type: ApiErrorType.unknown,
          message: 'Không giả lập được: không tìm thấy phiên thanh toán.',
        );
      }
    },
  );

  Future<T> _send<T>(
    Future<Response<Object?>> Function() request,
    T Function(Object? data) parse,
  ) async {
    try {
      final res = await request();
      return unwrapResponse<T>(res.data, parse);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}
