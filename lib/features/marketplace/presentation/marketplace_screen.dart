import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/platform.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/state_views.dart';
import '../domain/marketplace_connection.dart';
import 'marketplace_providers.dart';

/// Kết nối shop Shopee / TikTok Shop (chỉ Tenant Admin).
class MarketplaceScreen extends ConsumerWidget {
  const MarketplaceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kết nối sàn')),
      body: AsyncValueView(
        value: ref.watch(connectionsProvider),
        onRetry: () => ref.invalidate(connectionsProvider),
        data: (connections) => ListView(
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Mỗi cửa hàng kết nối tối đa 1 shop Shopee và 1 shop TikTok Shop.',
              ),
            ),
            for (final platform in Platform.values)
              _PlatformTile(
                platform: platform,
                connection: connections
                    .where((c) => c.platform == platform)
                    .firstOrNull,
              ),
          ],
        ),
      ),
    );
  }
}

class _PlatformTile extends ConsumerWidget {
  const _PlatformTile({required this.platform, this.connection});

  final Platform platform;
  final MarketplaceConnection? connection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = connection;
    return ListTile(
      leading: const Icon(Icons.storefront),
      title: Text(platform.label),
      subtitle: Text(
        c == null
            ? 'Chưa kết nối'
            : switch (c.status) {
                ConnectionStatus.connected =>
                  'Đã kết nối · shop ${c.shopId ?? ''}',
                ConnectionStatus.error => 'Lỗi kết nối - cần kết nối lại',
                ConnectionStatus.disconnected => 'Đã ngắt kết nối',
              },
      ),
      trailing: c == null || c.status != ConnectionStatus.connected
          ? FilledButton.tonal(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                builder: (_) => _ConnectSheet(platform: platform),
              ),
              child: const Text('Kết nối'),
            )
          : const Icon(Icons.check_circle, color: Colors.green),
    );
  }
}

class _ConnectSheet extends ConsumerStatefulWidget {
  const _ConnectSheet({required this.platform});

  final Platform platform;

  @override
  ConsumerState<_ConnectSheet> createState() => _ConnectSheetState();
}

class _ConnectSheetState extends ConsumerState<_ConnectSheet> {
  final _formKey = GlobalKey<FormState>();
  final _appKey = TextEditingController();
  final _appSecret = TextEditingController();
  bool _autoImport = true;
  bool _busy = false;

  @override
  void dispose() {
    _appKey.dispose();
    _appSecret.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(marketplaceRepositoryProvider)
          .connect(
            platform: widget.platform,
            appKey: _appKey.text.trim(),
            appSecret: _appSecret.text.trim(),
            autoImportProducts: _autoImport,
          );
      ref.invalidate(connectionsProvider);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      messenger.showSnackBar(
        SnackBar(content: Text('Đã kết nối ${widget.platform.label}')),
      );
    } catch (e) {
      if (mounted) showErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Kết nối ${widget.platform.label}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _appKey,
              decoration: const InputDecoration(labelText: 'App Key'),
              validator: (v) => Validators.required(v, field: 'App Key'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _appSecret,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'App Secret'),
              validator: (v) => Validators.required(v, field: 'App Secret'),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Tự động nhập sản phẩm từ shop'),
              value: _autoImport,
              onChanged: (v) => setState(() => _autoImport = v),
            ),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: const Text('Kết nối'),
            ),
          ],
        ),
      ),
    );
  }
}
