import 'package:flutter/material.dart';

import '../domain/onboarding_slide.dart';

/// Welcome photograph shown behind the first page.
///
/// To change it: replace the file under `assets/images/` (keep it a
/// compressed JPEG for slow networks). The painted city scene renders
/// underneath, so there is never a blank frame while the photo decodes.
const String welcomeHeroPhotoAsset = 'assets/images/welcome_hero.jpg';

abstract final class OnboardingContent {
  static const List<OnboardingSlide> slides = [
    OnboardingSlide(
      kicker: 'Welcome to Rent A Ride',
      kickerIcon: Icons.waving_hand_rounded,
      headline: 'Your ride.\nYour destination.',
      highlight: 'Your choice.',
      body:
          'Book a ride, send a package or explore new places across Abuja '
          'and beyond — safely and on time.',
      backdrop: OnboardingBackdrop.photo,
    ),
    OnboardingSlide(
      kicker: 'Fixed fare or negotiate',
      kickerIcon: Icons.payments_rounded,
      headline: 'Fair prices,',
      highlight: 'your way.',
      body:
          'Take an upfront fixed fare, or offer your own price and pick the '
          'driver offer that works for you.',
      backdrop: OnboardingBackdrop.cityScene,
    ),
    OnboardingSlide(
      kicker: 'Verified drivers only',
      kickerIcon: Icons.verified_rounded,
      headline: 'Safety first,',
      highlight: 'every trip.',
      body:
          'See your driver arrive live, share your trip with family and '
          'reach help with one tap on SOS.',
      backdrop: OnboardingBackdrop.liveMap,
    ),
  ];
}
