import 'dart:ui' show ImageFilter, PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:rar_design_system/rar_design_system.dart';

import '../../../../app/router/app_routes.dart';
import '../../../map/map_data.dart';
import '../../../map/ride_map.dart';
import '../../data/onboarding_content.dart';
import '../../domain/onboarding_slide.dart';
import '../widgets/welcome_hero.dart';

/// First screen of the passenger app: three swipeable full-screen pages
/// (photo, fares, safety) with the text, page dots and Next / Get Started
/// in a navy sheet at the bottom. Get Started (or Skip) opens the screen
/// to create an account, log in or continue with Google.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key, this.slides = OnboardingContent.slides});

  final List<OnboardingSlide> slides;

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final _pageController = PageController();
  int _page = 0;

  bool get _isLastPage => _page == widget.slides.length - 1;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToPage(int index) {
    if (index < 0 || index >= widget.slides.length) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _pageController.jumpToPage(index);
    } else {
      _pageController.animateToPage(
        index,
        duration: RarMotion.slow,
        curve: RarMotion.standard,
      );
    }
  }

  void _onPageChanged(int index) {
    HapticFeedback.selectionClick();
    setState(() => _page = index);
  }

  void _getStarted() => context.push(AppRoutes.getStarted);

  void _next() => _isLastPage ? _getStarted() : _goToPage(_page + 1);

  /// Swipes on the sheet turn pages too, like swiping the picture.
  void _onSheetDragEnd(DragEndDetails d) {
    final v = d.primaryVelocity ?? 0;
    if (v < -200) _goToPage(_page + 1);
    if (v > 200) _goToPage(_page - 1);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final gutter = RarResponsive.gutterFor(size.width);

    return Theme(
      data: RarTheme.dark(),
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light.copyWith(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: RarColors.navy950,
        ),
        child: Scaffold(
          backgroundColor: RarColors.navy,
          body: Stack(
            children: [
              // Swipeable full-screen backdrops.
              Positioned.fill(
                child: PageView.builder(
                  // Also allow mouse/trackpad drags (desktop testing).
                  scrollBehavior: ScrollConfiguration.of(context).copyWith(
                    dragDevices: PointerDeviceKind.values.toSet(),
                  ),
                  controller: _pageController,
                  itemCount: widget.slides.length,
                  onPageChanged: _onPageChanged,
                  itemBuilder: (context, i) => _Backdrop(
                    backdrop: widget.slides[i].backdrop,
                    sheetHeight: size.height * 0.44,
                  ),
                ),
              ),
              // Darken the top so the brand row stays readable.
              const Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 150,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0x99061B49), Color(0x00061B49)],
                      ),
                    ),
                  ),
                ),
              ),
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: gutter,
                    vertical: RarSpacing.sm,
                  ),
                  child: _TopBar(
                    showSkip: !_isLastPage,
                    onSkip: _getStarted,
                  ),
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: GestureDetector(
                  onHorizontalDragEnd: _onSheetDragEnd,
                  child: _Sheet(
                    slide: widget.slides[_page],
                    page: _page,
                    count: widget.slides.length,
                    isLastPage: _isLastPage,
                    gutter: gutter,
                    onNext: _next,
                    onDotTap: _goToPage,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Brand pill and Skip, both on frosted glass over the picture.
class _TopBar extends StatelessWidget {
  const _TopBar({required this.showSkip, required this.onSkip});

  final bool showSkip;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const _Frosted(
          padding: EdgeInsets.fromLTRB(6, 6, 16, 6),
          child: RarWordmark(logoSize: 30, fontSize: 16),
        ),
        const Spacer(),
        AnimatedOpacity(
          opacity: showSkip ? 1 : 0,
          duration: RarMotion.fast,
          child: IgnorePointer(
            ignoring: !showSkip,
            child: ExcludeSemantics(
              excluding: !showSkip,
              child: _Frosted(
                child: TextButton(
                  onPressed: onSkip,
                  style: TextButton.styleFrom(
                    foregroundColor: RarColors.white,
                    minimumSize: const Size(64, RarSpacing.minTouchTarget),
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                  ),
                  child: const Text('Skip'),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Frosted extends StatelessWidget {
  const _Frosted({required this.child, this.padding = EdgeInsets.zero});

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: RarRadius.pillShape,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: RarColors.navy.withValues(alpha: 0.72),
            borderRadius: RarRadius.pillShape,
            border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
          ),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Navy sheet with the page text, dots and actions.
class _Sheet extends StatelessWidget {
  const _Sheet({
    required this.slide,
    required this.page,
    required this.count,
    required this.isLastPage,
    required this.gutter,
    required this.onNext,
    required this.onDotTap,
  });

  final OnboardingSlide slide;
  final int page;
  final int count;
  final bool isLastPage;
  final double gutter;
  final VoidCallback onNext;
  final ValueChanged<int> onDotTap;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final compact = size.height < 700 || size.width < 350;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Container(
      width: double.infinity,
      constraints: BoxConstraints(maxHeight: size.height * 0.62),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xF20B2A6B), RarColors.navy950],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
        ),
        boxShadow: const [
          BoxShadow(color: Color(0x66000000), blurRadius: 30),
        ],
      ),
      child: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          gutter + 4,
          compact ? 22 : 28,
          gutter + 4,
          (compact ? 14 : 20) + bottomInset,
        ),
        child: RarContentWidth(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AnimatedSwitcher(
                duration: RarMotion.medium,
                layoutBuilder: (current, previous) => Stack(
                  alignment: Alignment.topLeft,
                  children: [...previous, ?current],
                ),
                child: _SlideText(
                  key: ValueKey(page),
                  slide: slide,
                  compact: compact,
                ),
              ),
              SizedBox(height: compact ? 18 : 24),
              Semantics(
                label: 'Page ${page + 1} of $count',
                child: Row(
                  children: [
                    for (var i = 0; i < count; i++)
                      Semantics(
                        button: true,
                        label: 'Go to page ${i + 1}',
                        excludeSemantics: true,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => onDotTap(i),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 10,
                            ).copyWith(right: 6),
                            child: AnimatedContainer(
                              duration: RarMotion.fast,
                              width: i == page ? 26 : 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: i == page
                                    ? RarColors.cyan
                                    : Colors.white.withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              SizedBox(height: compact ? 12 : 18),
              RarButton.primary(
                key: ValueKey(isLastPage ? 'get-started' : 'next'),
                label: isLastPage ? 'Get Started' : 'Next',
                trailingIcon: Icons.arrow_forward_rounded,
                onPressed: onNext,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SlideText extends StatelessWidget {
  const _SlideText({super.key, required this.slide, required this.compact});

  final OnboardingSlide slide;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(slide.kickerIcon, size: 16, color: RarColors.cyan),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                slide.kicker.toUpperCase(),
                style: RarTypography.caption.copyWith(
                  color: RarColors.cyan,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.4,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Semantics(
          header: true,
          label: slide.semanticHeadline,
          excludeSemantics: true,
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(text: '${slide.headline}\n'),
                TextSpan(
                  text: slide.highlight,
                  style: const TextStyle(color: RarColors.cyan),
                ),
              ],
            ),
            style: RarTypography.display.copyWith(
              fontSize: compact ? 26 : 30,
              height: 1.15,
              color: RarColors.white,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          slide.body,
          style: RarTypography.body.copyWith(
            color: RarColors.textOnDarkSecondary,
            height: 1.45,
          ),
        ),
      ],
    );
  }
}

/// Full-screen picture behind a page.
class _Backdrop extends StatelessWidget {
  const _Backdrop({required this.backdrop, required this.sheetHeight});

  final OnboardingBackdrop backdrop;
  final double sheetHeight;

  @override
  Widget build(BuildContext context) {
    return switch (backdrop) {
      OnboardingBackdrop.photo => const ExcludeSemantics(
        child: Stack(
          fit: StackFit.expand,
          children: [
            RepaintBoundary(child: CustomPaint(painter: CityScenePainter())),
            Image(
              image: AssetImage(welcomeHeroPhotoAsset),
              fit: BoxFit.cover,
              alignment: Alignment(0.2, -0.6),
            ),
          ],
        ),
      ),
      OnboardingBackdrop.cityScene => const ExcludeSemantics(
        child: RepaintBoundary(child: CustomPaint(painter: CityScenePainter())),
      ),
      OnboardingBackdrop.liveMap => _LiveMapBackdrop(sheetHeight: sheetHeight),
    };
  }
}

/// The drawn map with demo cars moving and a route to Jabi Lake Mall.
class _LiveMapBackdrop extends StatefulWidget {
  const _LiveMapBackdrop({required this.sheetHeight});

  final double sheetHeight;

  @override
  State<_LiveMapBackdrop> createState() => _LiveMapBackdropState();
}

class _LiveMapBackdropState extends State<_LiveMapBackdrop> {
  static const _origin = DemoPlacesRepository.currentSpot;
  late final Stream<List<NearbyDriver>> _drivers = const DemoNearbyDrivers()
      .watch(_origin.location);

  @override
  Widget build(BuildContext context) {
    final destination = DemoPlacesRepository.all.first;
    return ExcludeSemantics(
      child: IgnorePointer(
        child: StreamBuilder<List<NearbyDriver>>(
          stream: _drivers,
          builder: (context, snap) => RideMap(
            origin: _origin.location,
            drivers: snap.data ?? const [],
            destination: destination,
            fitPadding: EdgeInsets.fromLTRB(
              48,
              120,
              48,
              widget.sheetHeight + 24,
            ),
          ),
        ),
      ),
    );
  }
}
