import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rar_design_system/rar_design_system.dart';

import 'auth_screen.dart';

class _Page {
  const _Page(this.image, this.icon, this.kicker, this.headline, this.highlight, this.body);
  final String image;
  final IconData icon;
  final String kicker;
  final String headline;
  final String highlight;
  final String body;
}

const _pages = [
  _Page('assets/images/driver_intro_1.jpg', Icons.waving_hand_rounded, 'Drive with Rent A Ride',
      'Your car.\nYour hours.', 'Your earnings.',
      'Go online whenever it suits you and get ride requests from riders nearby across Abuja and beyond.'),
  _Page('assets/images/driver_intro_2.jpg', Icons.handshake_rounded, 'Fixed fares or negotiate',
      'Fair pay,', 'your way.',
      'Accept upfront fixed fares, or answer a rider’s offer with your own price. You always see the fare first.'),
  _Page('assets/images/driver_intro_3.jpg', Icons.verified_rounded, 'Verified community',
      'Safe for riders,', 'safe for you.',
      'Every driver and rider is verified. Trips are tracked live, riders are rated, and help is one tap away.'),
];

/// First screen for signed-out drivers: three swipeable full-screen pages,
/// then Get Started (sign up) or sign in.
class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key});
  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> {
  final _controller = PageController();
  int _page = 0;

  bool get _last => _page == _pages.length - 1;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _go(int i) {
    if (i < 0 || i >= _pages.length) return;
    _controller.animateToPage(i, duration: RarMotion.slow, curve: RarMotion.standard);
  }

  void _openAuth({required bool signUp}) => Navigator.of(context)
      .push(MaterialPageRoute<void>(builder: (_) => AuthScreen(startWithSignUp: signUp)));

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final p = _pages[_page];
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: RarColors.navy,
        body: Stack(children: [
          Positioned.fill(
            child: PageView.builder(
              controller: _controller,
              itemCount: _pages.length,
              onPageChanged: (i) {
                HapticFeedback.selectionClick();
                setState(() => _page = i);
              },
              itemBuilder: (_, i) => _Backdrop(asset: _pages[i].image, index: i),
            ),
          ),
          const Positioned(top: 0, left: 0, right: 0, height: 150,
              child: IgnorePointer(child: DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [Color(0x99061B49), Color(0x00061B49)]))))),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: RarSpacing.lg, vertical: RarSpacing.sm),
              child: Row(children: [
                const _Frosted(padding: EdgeInsets.fromLTRB(6, 6, 16, 6),
                    child: RarWordmark(logoSize: 30, fontSize: 16, subtitle: 'Driver')),
                const Spacer(),
                AnimatedOpacity(
                  opacity: _last ? 0 : 1,
                  duration: RarMotion.fast,
                  child: IgnorePointer(
                    ignoring: _last,
                    child: _Frosted(child: TextButton(
                      onPressed: () => _openAuth(signUp: true),
                      style: TextButton.styleFrom(foregroundColor: RarColors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 18)),
                      child: const Text('Skip'),
                    )),
                  ),
                ),
              ]),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: GestureDetector(
              onHorizontalDragEnd: (d) {
                final v = d.primaryVelocity ?? 0;
                if (v < -200) _go(_page + 1);
                if (v > 200) _go(_page - 1);
              },
              child: Container(
                width: double.infinity,
                constraints: BoxConstraints(maxHeight: size.height * 0.62),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
                      colors: [Color(0xF20B2A6B), RarColors.navy950]),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                  border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.12))),
                ),
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(RarSpacing.xl, RarSpacing.xl, RarSpacing.xl,
                      RarSpacing.lg + MediaQuery.paddingOf(context).bottom),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                    AnimatedSwitcher(
                      duration: RarMotion.medium,
                      layoutBuilder: (cur, prev) => Stack(alignment: Alignment.topLeft, children: [...prev, ?cur]),
                      child: Column(key: ValueKey(_page), crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Icon(p.icon, size: 16, color: RarColors.cyan),
                          const SizedBox(width: 8),
                          Text(p.kicker.toUpperCase(), style: RarTypography.caption.copyWith(
                              color: RarColors.cyan, fontWeight: FontWeight.w600, letterSpacing: 1.4)),
                        ]),
                        const SizedBox(height: 10),
                        Semantics(
                          header: true,
                          label: '${p.headline.replaceAll('\n', ' ')} ${p.highlight}',
                          excludeSemantics: true,
                          child: Text.rich(
                            TextSpan(children: [
                              TextSpan(text: '${p.headline}\n'),
                              TextSpan(text: p.highlight, style: const TextStyle(color: RarColors.cyan)),
                            ]),
                            style: RarTypography.display.copyWith(fontSize: size.height < 700 ? 26 : 30,
                                height: 1.15, color: RarColors.white),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(p.body, style: RarTypography.body.copyWith(color: RarColors.textOnDarkSecondary, height: 1.45)),
                      ]),
                    ),
                    const SizedBox(height: 22),
                    Semantics(
                      label: 'Page ${_page + 1} of ${_pages.length}',
                      child: Row(children: [
                        for (var i = 0; i < _pages.length; i++)
                          GestureDetector(
                            onTap: () => _go(i),
                            behavior: HitTestBehavior.opaque,
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(0, 10, 6, 10),
                              child: AnimatedContainer(
                                duration: RarMotion.fast,
                                width: i == _page ? 26 : 8, height: 8,
                                decoration: BoxDecoration(
                                  color: i == _page ? RarColors.cyan : Colors.white.withValues(alpha: 0.3),
                                  borderRadius: BorderRadius.circular(4)),
                              ),
                            ),
                          ),
                      ]),
                    ),
                    const SizedBox(height: 16),
                    RarButton.primary(
                      key: ValueKey(_last ? 'get-started' : 'next'),
                      label: _last ? 'Get Started' : 'Next',
                      trailingIcon: Icons.arrow_forward_rounded,
                      onPressed: () => _last ? _openAuth(signUp: true) : _go(_page + 1),
                    ),
                    if (_last) ...[
                      const SizedBox(height: 6),
                      Center(child: TextButton(
                        onPressed: () => _openAuth(signUp: false),
                        child: const Text('I already drive with Rent A Ride — sign in',
                            style: TextStyle(color: RarColors.textOnDarkSecondary)),
                      )),
                    ],
                  ]),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

/// Full-screen photo, or a branded gradient until the photo exists.
class _Backdrop extends StatelessWidget {
  const _Backdrop({required this.asset, required this.index});
  final String asset;
  final int index;

  @override
  Widget build(BuildContext context) {
    final fallback = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [const [Color(0xFF0B2A6B), Color(0xFF0A3A7A), Color(0xFF123A8F)][index], RarColors.navy950],
        ),
      ),
      child: Align(
        alignment: const Alignment(0, -0.45),
        child: Icon(const [Icons.directions_car_filled_rounded, Icons.handshake_rounded, Icons.verified_user_rounded][index],
            size: 120, color: RarColors.cyan.withValues(alpha: 0.35)),
      ),
    );
    return ExcludeSemantics(
      child: Image.asset(asset, fit: BoxFit.cover, alignment: const Alignment(0, -0.5),
          errorBuilder: (_, _, _) => fallback),
    );
  }
}

class _Frosted extends StatelessWidget {
  const _Frosted({required this.child, this.padding = EdgeInsets.zero});
  final Widget child;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) => ClipRRect(
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
