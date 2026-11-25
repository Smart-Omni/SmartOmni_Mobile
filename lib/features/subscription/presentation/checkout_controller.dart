import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/utils/clock.dart';
import '../domain/subscription.dart';
import 'subscription_providers.dart';

enum CheckoutPhase {
  /// Đang gọi `POST /checkout`.
  creating,

  /// Có mã QR, đang hỏi trạng thái mỗi [CheckoutController.pollInterval].
  waiting,
  paid,

  /// BE trả `EXPIRED`, hoặc quá `expiresAt` mà vẫn chưa thanh toán.
  expired,
  failed,

  /// Không tạo được phiên (vd. `SUBSCRIPTION_EARLY_RENEWAL_TOO_EARLY`).
  error,
}

class CheckoutState {
  const CheckoutState(
    this.phase, {
    this.session,
    this.error,
    this.canRetry = true,
    this.simulating = false,
  });

  final CheckoutPhase phase;
  final CheckoutSession? session;

  /// Câu lỗi khi [phase] là [CheckoutPhase.error].
  final String? error;

  /// `false` khi tạo lại cũng chắc chắn lỗi (gia hạn quá sớm).
  final bool canRetry;

  /// Đang gọi `simulate-pay` (chỉ bản dev).
  final bool simulating;

  CheckoutState copyWith({bool? simulating}) => CheckoutState(
    phase,
    session: session,
    error: error,
    canRetry: canRetry,
    simulating: simulating ?? this.simulating,
  );
}

/// Phiên thanh toán của sheet T-40. Provider `autoDispose`: sheet đóng là
/// provider bị hủy và ngừng hỏi trạng thái.
class CheckoutController extends Notifier<CheckoutState> {
  static const pollInterval = Duration(seconds: 5);

  late SubscriptionRepository _repo;
  late DateTime Function() _clock;
  Timer? _timer;
  var _checking = false;

  /// Tăng mỗi lần tạo phiên, để kết quả của phiên cũ không ghi đè phiên mới.
  var _generation = 0;

  @override
  CheckoutState build() {
    _repo = ref.watch(subscriptionRepositoryProvider);
    _clock = ref.watch(clockProvider);
    ref.onDispose(_stopPolling);
    unawaited(_create());
    return const CheckoutState(CheckoutPhase.creating);
  }

  /// "Tạo mã mới" sau khi hết hạn / thất bại / lỗi.
  Future<void> retry() {
    _stopPolling();
    state = const CheckoutState(CheckoutPhase.creating);
    return _create();
  }

  Future<void> _create() async {
    final generation = ++_generation;
    try {
      final session = await _repo.checkout();
      if (!ref.mounted || generation != _generation) return;
      state = CheckoutState(CheckoutPhase.waiting, session: session);
      _timer = Timer.periodic(pollInterval, (_) => checkNow());
    } catch (e) {
      if (!ref.mounted || generation != _generation) return;
      state = CheckoutState(
        CheckoutPhase.error,
        error: checkoutErrorMessage(e),
        canRetry: e is! ApiException || e.code != earlyRenewalTooEarlyCode,
      );
    }
  }

  /// Hỏi `GET /orders/{code}/status` một lần. Lỗi mạng thì bỏ qua, hỏi lại ở
  /// lần sau.
  Future<void> checkNow() async {
    final session = state.session;
    if (_checking || state.phase != CheckoutPhase.waiting || session == null) {
      return;
    }
    _checking = true;
    try {
      final status = await _repo.orderStatus(session.orderCode);
      if (!ref.mounted || state.session != session) return;
      switch (status) {
        case PaymentStatus.paid:
          _finish(CheckoutPhase.paid, session);
        case PaymentStatus.failed:
          _finish(CheckoutPhase.failed, session);
        case PaymentStatus.expired:
          _finish(CheckoutPhase.expired, session);
        case PaymentStatus.pending:
          // BE chỉ báo EXPIRED sau 24 giờ (lỗi P4) dù mã QR hết hạn sau 15
          // phút: quá `expiresAt` thì app tự coi là hết hạn.
          if (!_clock().isBefore(session.expiresAt)) {
            _finish(CheckoutPhase.expired, session);
          }
      }
    } on Object {
      // Hỏi lại ở lần sau.
    } finally {
      _checking = false;
    }
  }

  /// Chỉ bản dev. Trả câu lỗi, hoặc `null` khi đã gọi xong.
  Future<String?> simulatePay() async {
    final session = state.session;
    if (state.phase != CheckoutPhase.waiting || session == null) return null;
    state = state.copyWith(simulating: true);
    String? error;
    try {
      await _repo.simulatePay(session.orderCode);
    } on ApiException catch (e) {
      error = e.message;
    } on Object {
      error = 'Không giả lập được thanh toán.';
    }
    if (!ref.mounted || state.session != session) return error;
    state = state.copyWith(simulating: false);
    if (error == null) await checkNow();
    return error;
  }

  void _finish(CheckoutPhase phase, CheckoutSession session) {
    _stopPolling();
    state = CheckoutState(phase, session: session);
  }

  void _stopPolling() {
    _timer?.cancel();
    _timer = null;
  }
}

final checkoutControllerProvider =
    NotifierProvider.autoDispose<CheckoutController, CheckoutState>(
      CheckoutController.new,
    );
