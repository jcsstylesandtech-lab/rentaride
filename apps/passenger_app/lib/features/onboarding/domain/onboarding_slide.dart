import 'package:flutter/widgets.dart';

/// What fills the screen behind a welcome page.
enum OnboardingBackdrop {
  /// The welcome photograph.
  photo,

  /// Painted city skyline with a glowing ride route.
  cityScene,

  /// The drawn map with nearby cars moving and a route to a destination.
  liveMap,
}

/// One page of the welcome carousel: a full-screen backdrop with a
/// kicker, headline and short description in the sheet beneath it.
@immutable
class OnboardingSlide {
  const OnboardingSlide({
    required this.kicker,
    required this.kickerIcon,
    required this.headline,
    required this.highlight,
    required this.body,
    required this.backdrop,
  });

  /// Short label above the headline (e.g. "Fixed fare or negotiate").
  final String kicker;
  final IconData kickerIcon;

  /// Headline text rendered in white.
  final String headline;

  /// Final part of the headline, rendered in the cyan accent.
  final String highlight;
  final String body;
  final OnboardingBackdrop backdrop;

  /// Full headline for screen readers.
  String get semanticHeadline => '$headline $highlight';
}
