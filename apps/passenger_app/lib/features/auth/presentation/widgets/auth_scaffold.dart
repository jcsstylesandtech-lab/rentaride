import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:rar_design_system/rar_design_system.dart';

import '../../../../app/router/app_routes.dart';

/// Shared layout for authentication screens: navy glass background, back
/// button, title and subtitle, and a scrollable body that stays clear of
/// the keyboard.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.title,
    required this.children,
    this.subtitle,
    this.showBack = true,
    this.footer,
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;
  final bool showBack;

  /// Pinned below the scrolling content, e.g. "Already have an account?".
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final gutter = RarResponsive.gutterFor(MediaQuery.sizeOf(context).width);

    return Theme(
      data: RarTheme.dark(),
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
          backgroundColor: RarColors.navy,
          body: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: RarGradients.darkBackground,
            ),
            child: SafeArea(
              child: RarContentWidth(
                child: Column(
                  children: [
                    SizedBox(
                      height: RarSpacing.minTouchTarget + 8,
                      child: Row(
                        children: [
                          if (showBack)
                            Padding(
                              padding: const EdgeInsets.only(left: 4),
                              child: BackButton(
                                color: RarColors.white,
                                onPressed: () => context.canPop()
                                    ? context.pop()
                                    : context.go(AppRoutes.welcome),
                              ),
                            ),
                          const Spacer(),
                          Padding(
                            padding: EdgeInsets.only(right: gutter),
                            child: const RarLogo(size: 34),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: EdgeInsets.fromLTRB(
                          gutter,
                          RarSpacing.sm,
                          gutter,
                          RarSpacing.xxl,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Semantics(
                              header: true,
                              child: Text(
                                title,
                                style: RarTypography.headlineLarge.copyWith(
                                  color: RarColors.white,
                                ),
                              ),
                            ),
                            if (subtitle != null) ...[
                              const SizedBox(height: RarSpacing.sm),
                              Text(
                                subtitle!,
                                style: RarTypography.body.copyWith(
                                  color: RarColors.textOnDarkSecondary,
                                ),
                              ),
                            ],
                            const SizedBox(height: RarSpacing.xxl),
                            ...children,
                          ],
                        ),
                      ),
                    ),
                    if (footer != null)
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          gutter,
                          0,
                          gutter,
                          RarSpacing.md,
                        ),
                        child: footer,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "Already have an account? Log in"-style prompt with a link button.
class AuthSwitchPrompt extends StatelessWidget {
  const AuthSwitchPrompt({
    super.key,
    required this.prompt,
    required this.action,
    required this.onPressed,
  });

  final String prompt;
  final String action;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          prompt,
          style: RarTypography.body.copyWith(
            color: RarColors.textOnDarkSecondary,
          ),
        ),
        TextButton(onPressed: onPressed, child: Text(action)),
      ],
    );
  }
}

/// Test details shown only while the app runs against the demo backend.
class DemoModeHint extends StatelessWidget {
  const DemoModeHint({super.key, required this.lines});

  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(RarSpacing.md),
      decoration: BoxDecoration(
        color: RarColors.warning.withValues(alpha: 0.10),
        borderRadius: RarRadius.card,
        border: Border.all(color: RarColors.warning.withValues(alpha: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.science_rounded, color: RarColors.warning, size: 20),
          const SizedBox(width: RarSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Demo mode (no real SMS or server yet)',
                  style: RarTypography.caption.copyWith(
                    color: RarColors.warning,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                for (final line in lines)
                  SelectableText(
                    line,
                    style: RarTypography.bodySmall.copyWith(
                      color: RarColors.white,
                      fontSize: 12.5,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
