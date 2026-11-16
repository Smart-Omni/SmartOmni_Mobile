import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/user_role.dart';
import '../../../core/design/design.dart';
import '../../../core/models/platform.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/utils/formatters.dart';
import '../../../l10n/l10n.dart';
import '../../auth/presentation/auth_controller.dart';
import '../domain/marketplace_connection.dart';
import 'marketplace_oauth.dart';
import 'marketplace_providers.dart';

/// T-10 Kết nối sàn (chỉ Tenant Admin), DESIGN.md mục 8b: hai thẻ sàn.
/// Kết nối qua OAuth của sàn ([MarketplaceOAuthController]); BE `9558375`
/// đã bỏ kết nối bằng App Key.
/// - Mock: mọi thứ là dữ liệu mẫu, OAuth giả không mở trình duyệt.
/// - BE thật: trạng thái, kết nối, ngắt kết nối, công tắc tự nhập Shopee gọi
///   API. Công tắc tự nhập TikTok vẫn là mẫu (BE chưa có API).
/// Staff không được kết nối / ngắt kết nối (BE chỉ cho Tenant Admin).
class MarketplaceScreen extends ConsumerWidget {
  const MarketplaceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(connectionsProvider);
    final connectRemote = ref.watch(marketplaceUseRemoteProvider);
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
                      message: connectRemote
                          ? 'Công tắc tự nhập của TikTok Shop là dữ liệu mẫu, '
                                'backend chưa có API.'
                          : 'Kết nối sàn đang là dữ liệu mẫu.',
                    ),
                    const SizedBox(height: SoSpace.s16),
                    for (final (i, platform) in Platform.values.indexed) ...[
                      if (i > 0) const SizedBox(height: SoSpace.cardGap),
                      _PlatformCard(
                        platform: platform,
                        connection: connectionFor(connections, platform),
                      ),
                    ],
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

  /// Bắt đầu OAuth; kết quả báo qua [MarketplaceOAuthListener].
  Future<void> _connect() async {
    try {
      await ref.read(marketplaceOAuthProvider.notifier).connect(_platform);
    } catch (e) {
      if (mounted) showSoToast(context, oauthErrorMessage(context.l10n, e));
    }
  }

  Widget _connectButton({required Key key, required String label}) {
    final pending = ref.watch(marketplaceOAuthProvider);
    return SoButton(
      key: key,
      label: label,
      size: SoButtonSize.small,
      loading: pending == _platform,
      onPressed: _busy || pending != null ? null : _connect,
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.soColors;
    // Route T-10 chỉ cho Tenant Admin; vẫn chặn ở đây cho chắc.
    final canManage = ref.watch(currentRoleProvider) != UserRole.staff;
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
            if (canManage) ...[
              const SizedBox(height: SoSpace.s12),
              Align(
                alignment: Alignment.centerLeft,
                child: _connectButton(
                  key: Key('connect_$name'),
                  label: 'Kết nối',
                ),
              ),
            ],
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
                onChanged: _busy || !canManage ? null : _setAutoImport,
              ),
              const Divider(height: 1),
              if (canManage) ...[
                const SizedBox(height: SoSpace.s12),
                SoButton.secondary(
                  key: Key('disconnect_$name'),
                  label: 'Ngắt kết nối',
                  size: SoButtonSize.small,
                  expand: true,
                  onPressed: _busy ? null : _disconnect,
                ),
              ],
            ] else ...[
              const SizedBox(height: SoSpace.s12),
              SoBanner(
                key: Key('platform_error_$name'),
                tone: SoBannerTone.danger,
                title: 'Mất kết nối với ${_platform.label}',
                message: 'Đơn và tồn kho đang ngừng đồng bộ.',
              ),
              if (canManage) ...[
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
                      child: _connectButton(
                        key: Key('reconnect_$name'),
                        label: 'Kết nối lại',
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ],
        ],
      ),
    );
  }
}

/// Công tắc "Tự nhập sản phẩm & đơn" trên thẻ sàn.
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
