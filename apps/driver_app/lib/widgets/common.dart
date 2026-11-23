import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rar_design_system/rar_design_system.dart';

/// Dark navy page background used across the driver app.
class DriverScaffold extends StatelessWidget {
  const DriverScaffold({super.key, required this.child, this.appBar, this.bottomNavigationBar, this.padding = true});
  final Widget child;
  final PreferredSizeWidget? appBar;
  final Widget? bottomNavigationBar;
  final bool padding;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: RarColors.navy,
        appBar: appBar,
        bottomNavigationBar: bottomNavigationBar,
        body: DecoratedBox(
          decoration: const BoxDecoration(gradient: RarGradients.darkBackground),
          child: SafeArea(
            bottom: bottomNavigationBar == null,
            child: padding
                ? Padding(padding: const EdgeInsets.symmetric(horizontal: RarSpacing.lg), child: child)
                : child,
          ),
        ),
      ),
    );
  }
}

class LoadingScreen extends StatelessWidget {
  const LoadingScreen({super.key});
  @override
  Widget build(BuildContext context) => const DriverScaffold(
        child: Center(child: CircularProgressIndicator(color: RarColors.cyan)),
      );
}

class MessageScreen extends StatelessWidget {
  const MessageScreen({super.key, required this.icon, required this.title, required this.body, this.actionLabel, this.onAction});
  final IconData icon;
  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return DriverScaffold(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: RarColors.cyan),
            const SizedBox(height: RarSpacing.lg),
            Text(title, textAlign: TextAlign.center, style: RarTypography.headline.copyWith(color: RarColors.white)),
            const SizedBox(height: RarSpacing.sm),
            Text(body, textAlign: TextAlign.center,
                style: RarTypography.body.copyWith(color: RarColors.textOnDarkSecondary)),
            if (actionLabel != null) ...[
              const SizedBox(height: RarSpacing.xl),
              RarButton.primary(label: actionLabel!, onPressed: onAction),
            ],
          ],
        ),
      ),
    );
  }
}

/// Rounded translucent card.
class Panel extends StatelessWidget {
  const Panel({super.key, required this.child, this.padding = const EdgeInsets.all(RarSpacing.lg), this.color, this.borderColor});
  final Widget child;
  final EdgeInsets padding;
  final Color? color;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? RarColors.glassFillDark,
        borderRadius: RarRadius.card,
        border: Border.all(color: borderColor ?? RarColors.glassBorderDark),
      ),
      child: child,
    );
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip(this.status, {super.key});
  final String status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'approved' || 'completed' || 'active' => RarColors.success,
      'rejected' || 'suspended' || 'cancelled' => RarColors.danger,
      'pending' => RarColors.warning,
      _ => RarColors.cyan,
    };
    final label = status.replaceAll('_', ' ');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.16), borderRadius: RarRadius.pillShape),
      child: Text('${label[0].toUpperCase()}${label.substring(1)}',
          style: RarTypography.caption.copyWith(color: color, fontWeight: FontWeight.w600)),
    );
  }
}

void showSnack(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: error ? RarColors.danger : RarColors.navy700,
      behavior: SnackBarBehavior.floating,
    ));
}

TextStyle get onDarkMuted => RarTypography.bodySmall.copyWith(color: RarColors.textOnDarkSecondary);
