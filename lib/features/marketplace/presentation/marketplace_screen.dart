import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../app/config/app_config.dart';
import '../../../core/design/design.dart';
import '../../../core/models/platform.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/validators.dart';
import '../domain/marketplace_connection.dart';
import 'marketplace_providers.dart';

/// T-10 Kết nối sàn (chỉ Tenant Admin), DESIGN.md mục 8b: hai thẻ sàn +
/// hàng "Nâng cao: nhập App Key". Kết nối bằng App Key gọi API thật; danh
/// sách, ngắt kết nối và công tắc tự nhập là mock (backend chưa có API).
/// OAuth để sau.
class MarketplaceScreen extends ConsumerWidget {
  const MarketplaceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(connectionsProvider);
    final useMock = ref.watch(appConfigProvider).useMock;
    // Giữ dữ liệu cũ khi đang tải lại (sau khi bật/tắt, ngắt kết nối).
    final connections = async.value;

    return SoScaffold(
      appBar: const SoAppBar(title: 'Kết nối sàn'),
      scrollable: connections != null || async.hasError,
      slivers: [
        SliverPadding(
          padding: SoSpace.page,
          sliver: connections != null
              ? SliverList.list(
                  children: [
                    SoMockBanner(
                      message: useMock
                          ? 'Kết nối sàn đang là dữ liệu mẫu.'
                          : 'Trạng thái sàn là dữ liệu mẫu, backend chưa có '
                                'API. Kết nối bằng App Key gọi API thật.',
                    ),
                    const SizedBox(height: SoSpace.s16),
                    for (final (i, platform) in Platform.values.indexed) ...[
                      if (i > 0) const SizedBox(height: SoSpace.cardGap),
                      _PlatformCard(
                        platform: platform,
                        connection: connectionFor(connections, platform),
                      ),
                    ],
                    const SizedBox(height: SoSpace.group),
                    SoListGroup(
                      children: [
                        SoListRow(
                          key: const Key('marketplace_app_key'),
                          icon: LucideIcons.keyRound,
                          title: 'Nâng cao: nhập App Key',
                          onTap: () => showAppKeySheet(
                            context,
                            platform: Platform.values.firstWhere(
                              (p) => canConnect(connections, p),
                              orElse: () => Platform.shopee,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                )
              : async.hasError
              ? SliverToBoxAdapter(
                  child: SoEmptyState.error(
                    title: 'Không tải được kết nối sàn',
                    message: async.error is ApiException
                        ? (async.error! as ApiException).message
                        : null,
                    onAction: () => ref.invalidate(connectionsProvider),
                  ),
                )
              : const _Skeleton(),
        ),
      ],
    );
  }
}

/// Nhãn trạng thái kết nối (dùng ở T-10 và M-50).
extension ConnectionStatusUi on ConnectionStatus? {
  /// `null` = sàn chưa có kết nối nào.
  (String, SoStatus) get tag => switch (this) {
    ConnectionStatus.connected => ('Đã kết nối', SoStatus.success),
    ConnectionStatus.error => ('Lỗi kết nối', SoStatus.danger),
    ConnectionStatus.disconnected || null => ('Chưa kết nối', SoStatus.neutral),
  };
}

/// Mở sheet App Key với [platform] chọn sẵn; kết nối xong thì báo toast.
Future<void> showAppKeySheet(
  BuildContext context, {
  required Platform platform,
}) async {
  final connected = await showSoBottomSheet<Platform>(
    context: context,
    builder: (_) => _AppKeySheet(initial: platform),
  );
  if (connected != null && context.mounted) {
    showSoToast(context, 'Đã kết nối ${connected.label}');
  }
}

/// Thẻ một sàn: đã kết nối / lỗi / chưa kết nối (gồm cả đã ngắt).
class _PlatformCard extends ConsumerStatefulWidget {
  const _PlatformCard({required this.platform, required this.connection});

  final Platform platform;
  final MarketplaceConnection? connection;

  @override
  ConsumerState<_PlatformCard> createState() => _PlatformCardState();
}

class _PlatformCardState extends ConsumerState<_PlatformCard> {
  bool _busy = false;

  Platform get _platform => widget.platform;

  /// Chạy [action] (mock), tải lại danh sách; lỗi thì báo toast.
  Future<void> _run(Future<void> Function() action, String done) async {
    setState(() => _busy = true);
    try {
      await action();
      ref.invalidate(connectionsProvider);
      if (mounted) showSoToast(context, done);
    } catch (e) {
      if (mounted) {
        showSoToast(
          context,
          e is ApiException ? e.message : 'Kiểm tra kết nối mạng rồi thử lại.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _setAutoImport(bool enabled) => _run(
    () => ref
        .read(marketplaceRepositoryProvider)
        .setAutoImport(_platform, enabled: enabled),
    enabled ? 'Đã bật tự nhập sản phẩm & đơn' : 'Đã tắt tự nhập sản phẩm & đơn',
  );

  Future<void> _disconnect() async {
    final label = _platform.label;
    final ok = await showSoBottomSheet<bool>(
      context: context,
      builder: (sheetContext) => SoBottomSheet(
        title: 'Ngắt kết nối $label?',
        secondary: SoButton.secondary(
          key: const Key('disconnect_cancel'),
          label: 'Hủy',
          onPressed: () => Navigator.pop(sheetContext, false),
        ),
        primary: SoButton.danger(
          key: const Key('disconnect_confirm'),
          label: 'Ngắt kết nối',
          onPressed: () => Navigator.pop(sheetContext, true),
        ),
        child: Text(
          'Đơn, sản phẩm và tồn kho sẽ ngừng đồng bộ với shop này.',
          style: sheetContext.textTheme.bodyMedium,
        ),
      ),
    );
    if (!(ok ?? false) || !mounted) return;
    await _run(
      () => ref.read(marketplaceRepositoryProvider).disconnect(_platform),
      'Đã ngắt kết nối $label',
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.soColors;
    final conn = widget.connection;
    final status = conn?.status;
    final (label, tone) = status.tag;
    final name = _platform.name;
    final active =
        status == ConnectionStatus.connected ||
        status == ConnectionStatus.error;

    return Container(
      key: Key('platform_card_$name'),
      padding: SoSpace.card,
      decoration: SoShape.card(c),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: SoChannelTag(platform: _platform)),
              const SizedBox(width: SoSpace.s8),
              SoStatusTag(
                key: Key('platform_status_$name'),
                label: label,
                status: tone,
              ),
            ],
          ),
          if (!active || conn == null) ...[
            const SizedBox(height: SoSpace.s8),
            Text(
              'Kết nối để nhập đơn và sản phẩm từ ${_platform.label}.',
              style: context.textTheme.bodyMedium?.copyWith(color: c.ink2),
            ),
            const SizedBox(height: SoSpace.s12),
            Align(
              alignment: Alignment.centerLeft,
              child: SoButton(
                key: Key('connect_$name'),
                label: 'Kết nối',
                size: SoButtonSize.small,
                onPressed: () => showAppKeySheet(context, platform: _platform),
              ),
            ),
          ] else ...[
            const SizedBox(height: SoSpace.s12),
            Text(
              conn.shopName ?? _platform.label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: context.textTheme.titleMedium,
            ),
            const SizedBox(height: SoSpace.s8),
            _InfoRow(
              label: 'Shop ID',
              value: Text(
                conn.shopId ?? '—',
                key: Key('shop_id_$name'),
                style: context.soText.code,
              ),
            ),
            const SizedBox(height: SoSpace.s4),
            _InfoRow(
              label: 'Đồng bộ lần cuối',
              value: Text(
                Formatters.dateTime(conn.lastSyncedAt),
                style: context.textTheme.bodySmall?.copyWith(color: c.ink),
              ),
            ),
            if (status == ConnectionStatus.connected) ...[
              const SizedBox(height: SoSpace.s12),
              const Divider(height: 1),
              _AutoImportRow(
                switchKey: Key('auto_import_$name'),
                value: conn.autoImportProducts,
                onChanged: _busy ? null : _setAutoImport,
              ),
              const Divider(height: 1),
              const SizedBox(height: SoSpace.s12),
              SoButton.secondary(
                key: Key('disconnect_$name'),
                label: 'Ngắt kết nối',
                size: SoButtonSize.small,
                expand: true,
                onPressed: _busy ? null : _disconnect,
              ),
            ] else ...[
              const SizedBox(height: SoSpace.s12),
              SoBanner(
                key: Key('platform_error_$name'),
                tone: SoBannerTone.danger,
                title: 'Mất kết nối với ${_platform.label}',
                message:
                    'Đơn và tồn kho đang ngừng đồng bộ. Kết nối lại bằng App '
                    'Key của shop.',
              ),
              const SizedBox(height: SoSpace.s12),
              Row(
                children: [
                  Expanded(
                    child: SoButton.secondary(
                      key: Key('disconnect_$name'),
                      label: 'Ngắt kết nối',
                      size: SoButtonSize.small,
                      onPressed: _busy ? null : _disconnect,
                    ),
                  ),
                  const SizedBox(width: SoSpace.s12),
                  Expanded(
                    flex: 2,
                    child: SoButton(
                      key: Key('reconnect_$name'),
                      label: 'Kết nối lại',
                      size: SoButtonSize.small,
                      onPressed: _busy
                          ? null
                          : () => showAppKeySheet(context, platform: _platform),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }
}

/// Công tắc "Tự nhập sản phẩm & đơn" (thẻ sàn và sheet App Key).
class _AutoImportRow extends StatelessWidget {
  const _AutoImportRow({
    required this.switchKey,
    required this.value,
    required this.onChanged,
  });

  final Key switchKey;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Tự nhập sản phẩm & đơn',
              style: context.textTheme.bodyLarge,
            ),
          ),
          Switch(key: switchKey, value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

/// Nhãn footnote ink2 bên trái, giá trị bên phải.
class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final Widget value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: context.textTheme.bodySmall?.copyWith(
              color: context.soColors.ink2,
            ),
          ),
        ),
        const SizedBox(width: SoSpace.s12),
        value,
      ],
    );
  }
}

/// Sheet "Kết nối bằng App Key": chọn sàn, App Key, App Secret, tự nhập.
class _AppKeySheet extends ConsumerStatefulWidget {
  const _AppKeySheet({required this.initial});

  final Platform initial;

  @override
  ConsumerState<_AppKeySheet> createState() => _AppKeySheetState();
}

class _AppKeySheetState extends ConsumerState<_AppKeySheet> {
  final _formKey = GlobalKey<FormState>();
  final _appKey = TextEditingController();
  final _appSecret = TextEditingController();
  late Platform _platform = widget.initial;
  bool _autoImport = true;
  bool _obscure = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _appKey.dispose();
    _appSecret.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(marketplaceRepositoryProvider)
          .connect(
            platform: _platform,
            appKey: _appKey.text.trim(),
            appSecret: _appSecret.text.trim(),
            autoImportProducts: _autoImport,
          );
      ref.invalidate(connectionsProvider);
      if (mounted) Navigator.pop(context, _platform);
    } catch (e) {
      if (!mounted) return;
      setState(
        () => _error = e is ApiException
            ? e.message
            : 'Kiểm tra kết nối mạng rồi thử lại.',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: SoBottomSheet(
        title: 'Kết nối bằng App Key',
        secondary: SoButton.secondary(
          key: const Key('app_key_cancel'),
          label: 'Hủy',
          onPressed: _busy ? null : () => Navigator.pop(context),
        ),
        primary: SoButton(
          key: const Key('app_key_submit'),
          label: 'Kết nối',
          loading: _busy,
          onPressed: _submit,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SoSegmented<Platform>(
              key: const Key('app_key_platform'),
              selected: _platform,
              onChanged: (p) => setState(() {
                _platform = p;
                _error = null;
              }),
              segments: [
                for (final p in Platform.values)
                  SoSegment(value: p, label: p.label),
              ],
            ),
            const SizedBox(height: SoSpace.s16),
            if (_error != null) ...[
              SoBanner(
                key: const Key('app_key_error'),
                tone: SoBannerTone.danger,
                title: 'Chưa kết nối được',
                message: _error,
              ),
              const SizedBox(height: SoSpace.s16),
            ],
            SoTextField(
              key: const Key('app_key_field'),
              label: 'App Key',
              controller: _appKey,
              mono: true,
              textInputAction: TextInputAction.next,
              validator: (v) => Validators.required(v, field: 'App Key'),
            ),
            const SizedBox(height: SoSpace.s16),
            SoTextField(
              key: const Key('app_secret_field'),
              label: 'App Secret',
              controller: _appSecret,
              obscureText: _obscure,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              validator: (v) => Validators.required(v, field: 'App Secret'),
              suffix: IconButton(
                key: const Key('app_secret_toggle'),
                tooltip: _obscure ? 'Hiện App Secret' : 'Ẩn App Secret',
                icon: Icon(
                  _obscure ? LucideIcons.eye : LucideIcons.eyeOff,
                  color: context.soColors.ink2,
                ),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
            const SizedBox(height: SoSpace.s8),
            _AutoImportRow(
              switchKey: const Key('app_key_auto_import'),
              value: _autoImport,
              onChanged: (v) => setState(() => _autoImport = v),
            ),
          ],
        ),
      ),
    );
  }
}

/// Skeleton cùng hình hai thẻ sàn.
class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) {
    Widget card() => Container(
      padding: SoSpace.card,
      decoration: SoShape.card(context.soColors),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SoSkeleton(width: 96, height: 18),
              Spacer(),
              SoSkeleton(width: 88, height: 24),
            ],
          ),
          SizedBox(height: SoSpace.s12),
          SoSkeleton(width: 180, height: 20),
          SizedBox(height: SoSpace.s8),
          SoSkeleton(height: 14),
          SizedBox(height: SoSpace.s8),
          SoSkeleton(height: 14),
        ],
      ),
    );
    return SliverList.list(
      children: [
        const SoSkeleton(height: 36, radius: SoRadius.capsule),
        const SizedBox(height: SoSpace.s16),
        card(),
        const SizedBox(height: SoSpace.cardGap),
        card(),
      ],
    );
  }
}
