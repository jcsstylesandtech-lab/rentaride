import 'package:flutter/material.dart';

import '../tokens/rar_colors.dart';
import '../tokens/rar_effects.dart';
import '../tokens/rar_spacing.dart';

/// Skeleton loading placeholders ("content-shaped" loading states).
///
/// Use these instead of a spinner whenever the *layout* of incoming content
/// is known (lists, cards, profiles, fares, history). They make slow
/// networks feel faster and avoid layout jumps when data arrives. Keep
/// spinners for in-button actions (e.g. "Book Ride" while submitting).
///
/// ```dart
/// RarSkeletonSwitcher(
///   isLoading: state.isLoading,
///   skeleton: const SkeletonList(itemCount: 3),
///   child: OffersList(offers: state.offers),
/// )
/// ```
enum SkeletonTone {
  /// Light-grey-blue blocks on white / light-blue screens.
  light,

  /// Translucent blue blocks on navy / glass screens.
  dark,
}

class _SkeletonColors {
  const _SkeletonColors(this.base, this.highlight);
  final Color base;
  final Color highlight;

  static const light = _SkeletonColors(Color(0xFFE3EAF6), Color(0xFFF5F8FE));
  static const dark = _SkeletonColors(Color(0xFF24478F), Color(0xFF3A63B4));

  static _SkeletonColors of(SkeletonTone tone) =>
      tone == SkeletonTone.light ? light : dark;
}

class _SkeletonScope extends InheritedWidget {
  const _SkeletonScope({
    required this.colors,
    required this.animation,
    required this.shimmerBox,
    required super.child,
  });

  final _SkeletonColors colors;

  /// Null when motion is reduced (static placeholders).
  final Animation<double>? animation;

  /// The shimmer's render box: every shape positions the highlight relative
  /// to it, so one sweep travels across all shapes in sync.
  final RenderBox? Function() shimmerBox;

  @override
  bool updateShouldNotify(_SkeletonScope old) =>
      old.colors != colors || old.animation != animation;
}

_SkeletonColors _colorsOf(BuildContext context) =>
    context.dependOnInheritedWidgetOfExactType<_SkeletonScope>()?.colors ??
    (Theme.of(context).brightness == Brightness.dark
        ? _SkeletonColors.dark
        : _SkeletonColors.light);

/// Sweeps a soft highlight across all skeleton shapes beneath it, in sync.
///
/// Announces "Loading" once to screen readers and hides the placeholder
/// shapes themselves from accessibility. The sweep is disabled (static
/// blocks) when the OS asks for reduced motion.
class RarShimmer extends StatefulWidget {
  const RarShimmer({
    super.key,
    required this.child,
    this.tone,
    this.semanticLabel = 'Loading',
  });

  final Widget child;

  /// Defaults to the ambient theme brightness.
  final SkeletonTone? tone;
  final String semanticLabel;

  @override
  State<RarShimmer> createState() => _RarShimmerState();
}

class _RarShimmerState extends State<RarShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.tone == null
        ? _colorsOf(context)
        : _SkeletonColors.of(widget.tone!);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    final content = _SkeletonScope(
      colors: colors,
      animation: reduceMotion ? null : _controller,
      shimmerBox: () {
        final box = context.findRenderObject();
        return box is RenderBox && box.hasSize ? box : null;
      },
      child: ExcludeSemantics(child: widget.child),
    );

    return Semantics(
      label: widget.semanticLabel,
      liveRegion: true,
      container: true,
      child: content,
    );
  }
}

class _SlidingGradient extends GradientTransform {
  const _SlidingGradient(this.offset);

  /// -1 (highlight off the left edge) → 1 (off the right edge).
  final double offset;

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) =>
      Matrix4.translationValues(bounds.width * offset, 0, 0);
}

// ── Primitive shapes ────────────────────────────────────────────────────

/// Rectangular placeholder (images, buttons, map areas).
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    super.key,
    this.width,
    this.height = 16,
    this.borderRadius = const BorderRadius.all(Radius.circular(RarRadius.xs)),
  });

  final double? width;
  final double height;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_SkeletonScope>();
    final colors = _colorsOf(context);
    final shape = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(color: colors.base, borderRadius: borderRadius),
    );
    final animation = scope?.animation;
    if (scope == null || animation == null) return shape;

    return AnimatedBuilder(
      animation: animation,
      child: shape,
      builder: (context, child) => ShaderMask(
        // srcATop recolours only this shape's own opaque pixels.
        blendMode: BlendMode.srcATop,
        shaderCallback: (bounds) {
          final gradient = LinearGradient(
            colors: [colors.base, colors.highlight, colors.base],
            stops: const [0.35, 0.5, 0.65],
            transform: _SlidingGradient(animation.value * 2 - 1),
          );
          final shimmer = scope.shimmerBox();
          final me = context.findRenderObject();
          if (shimmer == null || me is! RenderBox || !me.attached) {
            return gradient.createShader(bounds);
          }
          final offset = me.localToGlobal(Offset.zero, ancestor: shimmer);
          return gradient.createShader(
            (Offset.zero & shimmer.size).shift(-offset),
          );
        },
        child: child,
      ),
    );
  }
}

/// One line of text. [widthFactor] is a fraction of the available width,
/// so lines of different lengths look like real paragraphs.
class SkeletonLine extends StatelessWidget {
  const SkeletonLine({super.key, this.widthFactor = 1, this.height = 12});

  final double widthFactor;
  final double height;

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      alignment: AlignmentDirectional.centerStart,
      widthFactor: widthFactor,
      child: SkeletonBox(
        height: height,
        borderRadius: BorderRadius.circular(height / 2),
      ),
    );
  }
}

/// Avatar / icon placeholder.
class SkeletonCircle extends StatelessWidget {
  const SkeletonCircle({super.key, this.size = 48});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SkeletonBox(
      width: size,
      height: size,
      borderRadius: BorderRadius.circular(size / 2),
    );
  }
}

// ── Composites ──────────────────────────────────────────────────────────

/// Card surface that holds skeleton content (white on light screens,
/// glass-blue on dark ones). Not itself shimmered.
class SkeletonCard extends StatelessWidget {
  const SkeletonCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(RarSpacing.lg),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: dark ? RarColors.glassFillDark : RarColors.white,
        borderRadius: RarRadius.card,
        border: Border.all(
          color: dark ? RarColors.glassBorderDark : RarColors.outlineLight,
        ),
        boxShadow: dark ? null : RarShadows.soft,
      ),
      child: child,
    );
  }
}

/// Avatar + title + subtitle (+ optional trailing value), e.g. a driver
/// offer, a trip in history, a transaction.
class SkeletonListTile extends StatelessWidget {
  const SkeletonListTile({
    super.key,
    this.avatarSize = 48,
    this.trailing = true,
    this.titleWidth = 0.55,
    this.subtitleWidth = 0.8,
  });

  final double avatarSize;
  final bool trailing;
  final double titleWidth;
  final double subtitleWidth;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SkeletonCircle(size: avatarSize),
        const SizedBox(width: RarSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SkeletonLine(widthFactor: titleWidth, height: 14),
              const SizedBox(height: RarSpacing.sm),
              SkeletonLine(widthFactor: subtitleWidth, height: 10),
            ],
          ),
        ),
        if (trailing) ...[
          const SizedBox(width: RarSpacing.md),
          const SkeletonBox(width: 56, height: 18),
        ],
      ],
    );
  }
}

/// A feed-style card: header tile followed by a short paragraph — the
/// layout in the reference loading screen.
class SkeletonPostCard extends StatelessWidget {
  const SkeletonPostCard({super.key, this.lines = 2});

  final int lines;

  @override
  Widget build(BuildContext context) {
    return SkeletonCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SkeletonListTile(trailing: false, avatarSize: 52),
          const SizedBox(height: RarSpacing.xl),
          for (var i = 0; i < lines; i++) ...[
            if (i > 0) const SizedBox(height: RarSpacing.sm),
            SkeletonLine(widthFactor: i.isEven ? 1 : 0.9),
          ],
        ],
      ),
    );
  }
}

/// [count] list tiles inside cards, shimmering together.
class SkeletonList extends StatelessWidget {
  const SkeletonList({super.key, this.itemCount = 3, this.tone});

  final int itemCount;
  final SkeletonTone? tone;

  @override
  Widget build(BuildContext context) {
    return RarShimmer(
      tone: tone,
      child: Column(
        children: [
          for (var i = 0; i < itemCount; i++) ...[
            if (i > 0) const SizedBox(height: RarSpacing.md),
            SkeletonCard(
              child: SkeletonListTile(
                titleWidth: i.isEven ? 0.55 : 0.45,
                subtitleWidth: i.isEven ? 0.8 : 0.7,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Cross-fades from [skeleton] to [child] when loading finishes.
class RarSkeletonSwitcher extends StatelessWidget {
  const RarSkeletonSwitcher({
    super.key,
    required this.isLoading,
    required this.skeleton,
    required this.child,
  });

  final bool isLoading;
  final Widget skeleton;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: RarMotion.medium,
      switchInCurve: RarMotion.standard,
      layoutBuilder: (current, previous) => Stack(
        alignment: Alignment.topCenter,
        children: [...previous, ?current],
      ),
      child: KeyedSubtree(
        key: ValueKey(isLoading),
        child: isLoading ? skeleton : child,
      ),
    );
  }
}
