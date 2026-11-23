import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:rar_design_system/rar_design_system.dart';

Widget _host(Widget child, {bool reduceMotion = false}) => MaterialApp(
  theme: RarTheme.light(),
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: reduceMotion),
    child: Scaffold(
      body: Padding(padding: const EdgeInsets.all(16), child: child),
    ),
  ),
);

void main() {
  testWidgets('skeleton list shimmers and announces loading', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_host(const SkeletonList(itemCount: 3)));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(SkeletonListTile), findsNWidgets(3));
    // Each placeholder shape carries its own slice of the sweep.
    expect(find.byType(ShaderMask), findsWidgets);
    expect(find.bySemanticsLabel('Loading'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('no shimmer animation when reduced motion is requested', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(const SkeletonList(itemCount: 1), reduceMotion: true),
    );
    expect(find.byType(ShaderMask), findsNothing);
    expect(find.byType(SkeletonListTile), findsOneWidget);
    // Nothing is animating, so the tree settles.
    await tester.pumpAndSettle();
  });

  testWidgets('switcher cross-fades from skeleton to content', (tester) async {
    Widget build(bool loading) => _host(
      RarSkeletonSwitcher(
        isLoading: loading,
        skeleton: const SkeletonList(itemCount: 2),
        child: const Text('Loaded'),
      ),
    );

    await tester.pumpWidget(build(true));
    expect(find.text('Loaded'), findsNothing);

    await tester.pumpWidget(build(false));
    await tester.pump(RarMotion.medium * 2);
    expect(find.text('Loaded'), findsOneWidget);
    expect(find.byType(SkeletonList), findsNothing);
  });

  testWidgets('dark tone renders inside a dark theme', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: RarTheme.dark(),
        home: const Scaffold(body: RarShimmer(child: SkeletonPostCard())),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byType(SkeletonPostCard), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
