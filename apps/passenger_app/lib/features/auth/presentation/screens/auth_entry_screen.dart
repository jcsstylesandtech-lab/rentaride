import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:rar_design_system/rar_design_system.dart';

import '../../../../app/router/app_routes.dart';
import '../../../onboarding/data/onboarding_content.dart';
import '../../../onboarding/presentation/widgets/welcome_hero.dart';
import '../widgets/auth_scaffold.dart';
import '../widgets/google_sign_in_button.dart';

/// Shown after the welcome pages' "Get Started": choose to create an
/// account, log in, or continue with Google.
class GetStartedScreen extends StatelessWidget {
  const GetStartedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).height < 700;

    return AuthScaffold(
      title: "Let's get you moving",
      subtitle: 'Create an account or log in to book your first ride.',
      footer: Text(
        'By continuing you agree to the Rent A Ride Terms of Service '
        'and Privacy Policy.',
        textAlign: TextAlign.center,
        style: RarTypography.caption.copyWith(color: RarColors.textMuted),
      ),
      children: [
        _HeroCard(height: compact ? 150 : 210),
        SizedBox(height: compact ? RarSpacing.lg : RarSpacing.xl),
        RarButton.primary(
          key: const ValueKey('sign-up'),
          label: 'Create Account',
          trailingIcon: Icons.arrow_forward_rounded,
          onPressed: () => context.push(AppRoutes.signUp),
        ),
        const SizedBox(height: RarSpacing.md),
        RarButton.glass(
          key: const ValueKey('log-in'),
          label: 'Log In',
          onPressed: () => context.push(AppRoutes.logIn),
        ),
        const SizedBox(height: RarSpacing.lg),
        const OrDivider(),
        const SizedBox(height: RarSpacing.lg),
        const GoogleSignInButton(),
      ],
    );
  }
}

/// Rounded picture of the welcome photo over the painted city.
class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: SizedBox(
          height: height,
          child: Stack(
            fit: StackFit.expand,
            children: [
              const CustomPaint(painter: CityScenePainter()),
              const Image(
                image: AssetImage(welcomeHeroPhotoAsset),
                fit: BoxFit.cover,
                alignment: Alignment(0.2, -0.55),
              ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x00061B49), Color(0xCC061B49)],
                    stops: [0.45, 1],
                  ),
                ),
              ),
              Positioned(
                left: 16,
                bottom: 14,
                child: Row(
                  children: [
                    const Icon(
                      Icons.verified_rounded,
                      size: 16,
                      color: RarColors.cyan,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Verified drivers  ·  Fixed or negotiated fares',
                      style: RarTypography.caption.copyWith(
                        color: RarColors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
