import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/design/design.dart';
import '../../../core/models/platform.dart';
import '../../../core/network/api_exception.dart';
import '../../../l10n/l10n.dart';
import '../domain/marketplace_connection.dart';
import 'marketplace_providers.dart';

/// Nguồn deep link: link mở app lúc khởi động (app đã bị tắt khi ở trình
/// duyệt) và link đến khi app đang chạy.
abstract class DeepLinkSource {
  Future<Uri?> initialLink();
  Stream<Uri> get links;
}

class AppLinksSource implements DeepLinkSource {
  final _appLinks = AppLinks();

  @override
  Future<Uri?> initialLink() => _appLinks.getInitialLink();

  @override
  Stream<Uri> get links => _appLinks.uriLinkStream;
}

final deepLinkSourceProvider = Provider<DeepLinkSource>(
  (ref) => AppLinksSource(),
);

/// Mở trang ủy quyền của sàn ngoài app (trình duyệt / app của sàn).
typedef UrlOpener = Future<bool> Function(Uri url);

final urlOpenerProvider = Provider<UrlOpener>(
  (ref) =>
      (url) => launchUrl(url, mode: LaunchMode.externalApplication),
);

/// Sàn đang chờ deep link OAuth. Lưu xuống máy vì Android có thể tắt app
/// trong lúc người bán ở trình duyệt.
abstract class OAuthPendingStore {
  Future<Platform?> read();
  Future<void> write(Platform platform);
  Future<void> clear();
}

class SecureOAuthPendingStore implements OAuthPendingStore {
  SecureOAuthPendingStore([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'marketplace_oauth_pending';
  final FlutterSecureStorage _storage;

  @override
  Future<Platform?> read() async {
    final v = await _storage.read(key: _key);
    return Platform.values.where((p) => p.name == v).firstOrNull;
  }

  @override
  Future<void> write(Platform platform) =>
      _storage.write(key: _key, value: platform.name);

  @override
  Future<void> clear() => _storage.delete(key: _key);
}

class InMemoryOAuthPendingStore implements OAuthPendingStore {
  InMemoryOAuthPendingStore([this.value]);

  Platform? value;

  @override
  Future<Platform?> read() async => value;

  @override
  Future<void> write(Platform platform) async => value = platform;

  @override
  Future<void> clear() async => value = null;
}

final oauthPendingStoreProvider = Provider<OAuthPendingStore>(
  (ref) => SecureOAuthPendingStore(),
);

/// Không mở được trang ủy quyền (không có trình duyệt…).
class OAuthLaunchFailure implements Exception {
  const OAuthLaunchFailure();
}

/// Kết quả một lần OAuth: [error] null = đã kết nối. [denied]: deep link có
/// `error` (người bán bấm từ chối trên trang của sàn).
class OAuthOutcome {
  const OAuthOutcome(this.platform, {this.error, this.denied = false});

  final Platform platform;
  final Object? error;
  final bool denied;
}

/// Câu tiếng Việt cho lỗi khi bắt đầu hoặc hoàn tất OAuth.
String oauthErrorMessage(AppLocalizations l10n, Object error) {
  if (error is OAuthLaunchFailure) return l10n.marketplaceOauthLaunchFailed;
  if (error is! ApiException) return 'Kiểm tra kết nối mạng rồi thử lại.';
  // Mã lỗi của BE có tiền tố sàn: SHOPEE_STATE_INVALID, TIKTOK_STATE_EXPIRED…
  final code = error.code ?? '';
  return switch (code) {
    'INVALID_REDIRECT_URI' => l10n.marketplaceOauthInvalidRedirect,
    _ when code.endsWith('_STATE_INVALID') => l10n.marketplaceOauthStateInvalid,
    _ when code.endsWith('_STATE_EXPIRED') => l10n.marketplaceOauthStateExpired,
    _ when code.endsWith('_STATE_REUSED') => l10n.marketplaceOauthStateReused,
    _ when code.endsWith('_AUTHORIZATION_DENIED') =>
      l10n.marketplaceOauthDenied,
    _ => error.message,
  };
}

/// Câu hiện sau một lần OAuth.
String oauthOutcomeMessage(AppLocalizations l10n, OAuthOutcome o) {
  if (o.denied) return l10n.marketplaceOauthDenied;
  final error = o.error;
  return error == null
      ? l10n.marketplaceOauthConnected(o.platform.label)
      : oauthErrorMessage(l10n, error);
}

/// Kết quả OAuth để [MarketplaceOAuthListener] báo toast (ở bất kỳ màn nào).
final oauthOutcomesProvider = Provider<StreamController<OAuthOutcome>>((ref) {
  final controller = StreamController<OAuthOutcome>.broadcast();
  ref.onDispose(controller.close);
  return controller;
});

/// Điều phối OAuth T-10. State: sàn đang chờ deep link (null = không chờ).
///
/// 1. [connect]: BE trả `authorizationUrl` → ghi nhớ sàn đang chờ → mở ngoài
///    app.
/// 2. [handleLink]: deep link `smartomni://oauth/<sàn>` khi đang chờ đúng sàn
///    → `POST …/callback` → tải lại trạng thái → báo kết quả. Link lạ, hoặc
///    không có lần Kết nối nào đang chờ, thì bỏ qua.
/// 3. Quay lại app mà không có deep link ([onResumed], hoặc mở lại app sau
///    khi bị tắt mà không có link) = người dùng hủy: bỏ chờ, không báo lỗi.
class MarketplaceOAuthController extends Notifier<Platform?> {
  /// Deep link thường đến ngay sau khi app trở lại; quá chừng này mà chưa có
  /// thì coi là người dùng tự quay lại.
  static const resumeGrace = Duration(seconds: 3);

  Timer? _resumeTimer;
  Uri? _lastLink;

  @override
  Platform? build() {
    ref.onDispose(() => _resumeTimer?.cancel());
    return null;
  }

  OAuthPendingStore get _store => ref.read(oauthPendingStoreProvider);

  Future<void> connect(Platform platform) async {
    if (state != null) return;
    state = platform;
    try {
      final start = await ref
          .read(marketplaceRepositoryProvider)
          .startAuthorization(platform);
      await _store.write(platform);
      final url = start.authorizationUrl;
      // Mock trả thẳng deep link sàn sẽ gọi về: xử lý luôn, không mở trình
      // duyệt.
      if (url.scheme == oauthScheme) return handleLink(url);
      if (!await ref.read(urlOpenerProvider)(url)) {
        throw const OAuthLaunchFailure();
      }
    } catch (_) {
      await _clear();
      rethrow;
    }
  }

  Future<void> handleLink(Uri uri) async {
    final callback = OAuthCallback.tryParse(uri);
    // Link đầu tiên có thể đến cả qua `initialLink` lẫn stream: chỉ xử lý một
    // lần (state chỉ dùng được một lần ở BE).
    if (callback == null || uri == _lastLink) return;
    _lastLink = uri;
    final pending = state ?? await _store.read();
    if (pending != callback.platform) return;
    _resumeTimer?.cancel();
    await _clear();

    final outcomes = ref.read(oauthOutcomesProvider);
    try {
      await ref
          .read(marketplaceRepositoryProvider)
          .completeAuthorization(callback);
      outcomes.add(OAuthOutcome(callback.platform));
    } catch (e) {
      outcomes.add(
        OAuthOutcome(callback.platform, error: e, denied: callback.denied),
      );
    }
    ref.invalidate(connectionsProvider);
  }

  /// App trở lại foreground.
  void onResumed() {
    if (state == null) return;
    _resumeTimer?.cancel();
    _resumeTimer = Timer(resumeGrace, _clear);
  }

  /// App mở lại (sau khi bị tắt) không kèm deep link: bỏ lần chờ cũ.
  Future<void> dropStale() => _clear();

  Future<void> _clear() async {
    state = null;
    try {
      await _store.clear();
    } catch (_) {
      // Không xóa được bộ nhớ máy: lần mở app sau sẽ thử lại.
    }
  }
}

final marketplaceOAuthProvider =
    NotifierProvider<MarketplaceOAuthController, Platform?>(
      MarketplaceOAuthController.new,
    );

/// Nghe deep link OAuth cho cả app (đặt dưới `MaterialApp`) và báo kết quả
/// bằng toast.
class MarketplaceOAuthListener extends ConsumerStatefulWidget {
  const MarketplaceOAuthListener({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<MarketplaceOAuthListener> createState() =>
      _MarketplaceOAuthListenerState();
}

class _MarketplaceOAuthListenerState
    extends ConsumerState<MarketplaceOAuthListener>
    with WidgetsBindingObserver {
  StreamSubscription<Uri>? _links;
  StreamSubscription<OAuthOutcome>? _outcomes;

  MarketplaceOAuthController get _oauth =>
      ref.read(marketplaceOAuthProvider.notifier);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _outcomes = ref.read(oauthOutcomesProvider).stream.listen(_show);
    final source = ref.read(deepLinkSourceProvider);
    _links = source.links.listen(_oauth.handleLink, onError: (_) {});
    unawaited(_handleInitial(source));
  }

  Future<void> _handleInitial(DeepLinkSource source) async {
    Uri? initial;
    try {
      initial = await source.initialLink();
    } catch (_) {
      initial = null;
    }
    if (!mounted) return;
    await (initial == null ? _oauth.dropStale() : _oauth.handleLink(initial));
  }

  void _show(OAuthOutcome outcome) {
    if (!mounted) return;
    showSoToast(context, oauthOutcomeMessage(context.l10n, outcome));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _oauth.onResumed();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _links?.cancel();
    _outcomes?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
