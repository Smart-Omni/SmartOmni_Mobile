import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/design/so_theme.dart';
import '../l10n/l10n.dart';
import 'config/app_config.dart';
import 'router/app_router.dart';

class SmartOmniApp extends ConsumerWidget {
  const SmartOmniApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);
    return MaterialApp.router(
      onGenerateTitle: (context) => context.l10n.appTitle,
      debugShowCheckedModeBanner: !config.isProd,
      // Đợt 1 chỉ có giao diện sáng (docs/DESIGN.md).
      theme: SoTheme.light(),
      themeMode: ThemeMode.light,
      routerConfig: ref.watch(routerProvider),
      locale: const Locale('vi'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
    );
  }
}
