import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'so_text.dart';
import 'so_tokens.dart';

/// Ô nhập: nhãn nằm trên, viền 1px, focus 2px brand, lỗi 2px danger.
///
/// Dùng trong [Form] như `TextFormField` (có [validator]). Truyền [errorText]
/// khi lỗi đến từ server (vd. sai mật khẩu). [mono] cho mã, số lượng.
class SoTextField extends StatelessWidget {
  const SoTextField({
    super.key,
    required this.label,
    this.controller,
    this.hint,
    this.helper,
    this.errorText,
    this.errorKey,
    this.validator,
    this.onChanged,
    this.onSubmitted,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.inputFormatters,
    this.obscureText = false,
    this.enabled = true,
    this.mono = false,
    this.textAlign = TextAlign.start,
    this.prefix,
    this.suffix,
    this.maxLines = 1,
  });

  final String label;
  final TextEditingController? controller;
  final String? hint;
  final String? helper;
  final String? errorText;

  /// Key gắn vào dòng [errorText] (để test tìm được).
  final Key? errorKey;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final List<TextInputFormatter>? inputFormatters;
  final bool obscureText;
  final bool enabled;
  final bool mono;
  final TextAlign textAlign;
  final Widget? prefix;

  /// Thường là `IconButton` (vd. hiện/ẩn mật khẩu).
  final Widget? suffix;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final c = context.soColors;
    final textStyle = mono
        ? context.soText.numeral
        : context.textTheme.bodyMedium;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: context.textTheme.labelLarge?.copyWith(color: c.ink2),
        ),
        const SizedBox(height: SoSpace.s4),
        TextFormField(
          controller: controller,
          validator: validator,
          onChanged: onChanged,
          onFieldSubmitted: onSubmitted,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          autofillHints: autofillHints,
          inputFormatters: inputFormatters,
          obscureText: obscureText,
          enabled: enabled,
          textAlign: textAlign,
          maxLines: obscureText ? 1 : maxLines,
          style: textStyle?.copyWith(color: enabled ? c.ink : c.muted),
          decoration: InputDecoration(
            hintText: hint,
            helperText: helper,
            error: errorText == null
                ? null
                : Text(
                    errorText!,
                    key: errorKey,
                    style: context.textTheme.bodySmall?.copyWith(
                      color: c.danger,
                    ),
                  ),
            prefixIcon: prefix,
            suffixIcon: suffix,
            fillColor: enabled ? c.surface : c.surfaceSunken,
            constraints: const BoxConstraints(minHeight: SoSize.control),
          ),
        ),
      ],
    );
  }
}
