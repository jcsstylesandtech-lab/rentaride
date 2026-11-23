import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rent_a_ride_passenger/app/app.dart';

bool _fontsLoaded = false;

/// Loads the real Poppins files from the design-system package so text in
/// tests is measured exactly as on a device (the default test font has
/// different metrics and would hide or invent overflow problems).
Future<void> loadBrandFonts() async {
  if (_fontsLoaded) return;
  final dir = Directory('../../packages/rar_design_system/assets/fonts');
  final loader = FontLoader('packages/rar_design_system/Poppins');
  for (final file in dir.listSync().whereType<File>()) {
    if (file.path.endsWith('.ttf')) {
      final bytes = file.readAsBytesSync();
      loader.addFont(
        Future.value(ByteData.sublistView(Uint8List.fromList(bytes))),
      );
    }
  }
  await loader.load();
  _fontsLoaded = true;
}

/// Sets the logical screen size and text scale for a test.
void setScreen(
  WidgetTester tester,
  Size logicalSize, {
  double textScale = 1.0,
}) {
  tester.view.devicePixelRatio = 2.0;
  tester.view.physicalSize = logicalSize * 2.0;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

/// Pumps the full app (router, theme, providers) and lets the entrance
/// animation finish.
Future<void> pumpApp(WidgetTester tester) async {
  await tester.pumpWidget(const ProviderScope(child: RentARideApp()));
  await tester.pumpAndSettle();
}
