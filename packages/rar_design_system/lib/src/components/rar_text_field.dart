import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../tokens/rar_colors.dart';
import '../tokens/rar_spacing.dart';
import '../tokens/rar_typography.dart';

/// Labelled text field in the Rent A Ride style. Follows the ambient theme
/// (glass on dark screens, white on light ones).
///
/// Set [obscure] for passwords: a show/hide toggle is added automatically.
class RarTextField extends StatefulWidget {
  const RarTextField({
    super.key,
    required this.label,
    this.controller,
    this.hint,
    this.prefixIcon,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.validator,
    this.onFieldSubmitted,
    this.onChanged,
    this.inputFormatters,
    this.obscure = false,
    this.enabled = true,
    this.autofocus = false,
    this.textCapitalization = TextCapitalization.none,
    this.helper,
  });

  final String label;
  final TextEditingController? controller;
  final String? hint;
  final IconData? prefixIcon;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onFieldSubmitted;
  final ValueChanged<String>? onChanged;
  final List<TextInputFormatter>? inputFormatters;
  final bool obscure;
  final bool enabled;
  final bool autofocus;
  final TextCapitalization textCapitalization;
  final String? helper;

  @override
  State<RarTextField> createState() => _RarTextFieldState();
}

class _RarTextFieldState extends State<RarTextField> {
  late bool _hidden = widget.obscure;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final labelColor =
        dark ? RarColors.textOnDarkSecondary : RarColors.textSecondary;
    final iconColor = dark ? RarColors.textOnDarkMuted : RarColors.textMuted;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: RarSpacing.xs + 2),
          child: Text(
            widget.label,
            style: RarTypography.caption.copyWith(
              color: labelColor,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        TextFormField(
          controller: widget.controller,
          enabled: widget.enabled,
          autofocus: widget.autofocus,
          obscureText: _hidden,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction,
          autofillHints: widget.autofillHints,
          validator: widget.validator,
          onFieldSubmitted: widget.onFieldSubmitted,
          onChanged: widget.onChanged,
          inputFormatters: widget.inputFormatters,
          textCapitalization: widget.textCapitalization,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          style: RarTypography.body.copyWith(
            fontSize: 15,
            color: dark ? RarColors.white : RarColors.navy,
          ),
          cursorColor: dark ? RarColors.cyan : RarColors.royal,
          decoration: InputDecoration(
            hintText: widget.hint,
            helperText: widget.helper,
            helperMaxLines: 2,
            errorMaxLines: 3,
            prefixIcon: widget.prefixIcon == null
                ? null
                : Icon(widget.prefixIcon, color: iconColor, size: 20),
            suffixIcon: widget.obscure
                ? IconButton(
                    tooltip: _hidden ? 'Show password' : 'Hide password',
                    icon: Icon(
                      _hidden
                          ? Icons.visibility_rounded
                          : Icons.visibility_off_rounded,
                      color: iconColor,
                      size: 20,
                    ),
                    onPressed: () => setState(() => _hidden = !_hidden),
                  )
                : null,
          ),
        ),
      ],
    );
  }
}

/// One-time-code input: [length] boxes backed by a single text field, so
/// paste and SMS autofill ("From Messages" on iOS) work naturally.
class RarOtpField extends StatefulWidget {
  const RarOtpField({
    super.key,
    required this.onCompleted,
    this.controller,
    this.length = 6,
    this.hasError = false,
    this.enabled = true,
    this.autofocus = true,
    this.onChanged,
  });

  final ValueChanged<String> onCompleted;
  final ValueChanged<String>? onChanged;
  final TextEditingController? controller;
  final int length;
  final bool hasError;
  final bool enabled;
  final bool autofocus;

  @override
  State<RarOtpField> createState() => _RarOtpFieldState();
}

class _RarOtpFieldState extends State<RarOtpField> {
  late final TextEditingController _controller =
      widget.controller ?? TextEditingController();
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_changed);
    _focus.addListener(() => setState(() {}));
  }

  void _changed() {
    setState(() {});
    final text = _controller.text;
    widget.onChanged?.call(text);
    if (text.length == widget.length) widget.onCompleted(text);
  }

  @override
  void dispose() {
    _controller.removeListener(_changed);
    if (widget.controller == null) _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final text = _controller.text;

    return Semantics(
      label: 'Verification code, ${widget.length} digits',
      textField: true,
      child: Stack(
        children: [
          Row(
            children: [
              for (var i = 0; i < widget.length; i++) ...[
                if (i > 0) const SizedBox(width: RarSpacing.sm),
                Expanded(child: _box(i, text, dark)),
              ],
            ],
          ),
          // The real input sits invisibly over the boxes.
          Positioned.fill(
            child: Opacity(
              opacity: 0,
              child: TextField(
                key: const ValueKey('otp-input'),
                controller: _controller,
                focusNode: _focus,
                enabled: widget.enabled,
                autofocus: widget.autofocus,
                keyboardType: TextInputType.number,
                autofillHints: const [AutofillHints.oneTimeCode],
                maxLength: widget.length,
                showCursor: false,
                enableInteractiveSelection: false,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  counterText: '',
                  border: InputBorder.none,
                  filled: false,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _box(int i, String text, bool dark) {
    final filled = i < text.length;
    final active = _focus.hasFocus &&
        (i == text.length ||
            (i == widget.length - 1 && text.length == widget.length));
    final borderColor = widget.hasError
        ? RarColors.danger
        : active
            ? (dark ? RarColors.cyan : RarColors.royal)
            : (dark ? RarColors.glassBorderDark : RarColors.outlineLight);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      height: 56,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: dark ? RarColors.glassFillDark : RarColors.white,
        borderRadius: RarRadius.card,
        border: Border.all(color: borderColor, width: active ? 1.8 : 1.2),
      ),
      child: Text(
        filled ? text[i] : '',
        style: RarTypography.headline.copyWith(
          color: dark ? RarColors.white : RarColors.navy,
        ),
      ),
    );
  }
}

/// Inline message (error, info or success) shown above a form's actions.
class RarInlineMessage extends StatelessWidget {
  const RarInlineMessage.error(this.message, {super.key, this.action})
      : _kind = _Kind.error;
  const RarInlineMessage.info(this.message, {super.key, this.action})
      : _kind = _Kind.info;
  const RarInlineMessage.success(this.message, {super.key, this.action})
      : _kind = _Kind.success;

  final String message;
  final Widget? action;
  final _Kind _kind;

  @override
  Widget build(BuildContext context) {
    final (color, icon) = switch (_kind) {
      _Kind.error => (RarColors.danger, Icons.error_rounded),
      _Kind.info => (RarColors.cyan, Icons.info_rounded),
      _Kind.success => (RarColors.success, Icons.check_circle_rounded),
    };
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(RarSpacing.md),
        decoration: BoxDecoration(
          color: color.withValues(alpha: dark ? 0.14 : 0.08),
          borderRadius: RarRadius.card,
          border: Border.all(color: color.withValues(alpha: 0.45)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: RarSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message,
                    style: RarTypography.bodySmall.copyWith(
                      fontSize: 13,
                      color: dark ? RarColors.white : RarColors.navy,
                    ),
                  ),
                  if (action != null) action!,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _Kind { error, info, success }
