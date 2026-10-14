import 'package:flutter/widgets.dart';

import 'generated/app_localizations.dart';

export 'generated/app_localizations.dart';

/// Viết tắt: `context.l10n.loginTitle` thay vì `AppLocalizations.of(context).loginTitle`.
///
/// Thêm chuỗi mới: sửa `lib/l10n/app_vi.arb` + `app_en.arb`, rồi chạy
/// `flutter gen-l10n` (hoặc `flutter run` sẽ tự sinh).
extension L10nX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
