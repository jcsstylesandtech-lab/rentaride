import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:rar_design_system/rar_design_system.dart';

import 'router/app_router.dart';

class RentARideApp extends ConsumerWidget {
  const RentARideApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'Rent A Ride',
      debugShowCheckedModeBanner: false,
      theme: RarTheme.light(),
      darkTheme: RarTheme.dark(),
      themeMode: ThemeMode.light,
      routerConfig: router,
      builder: (context, child) {
        final media = MediaQuery.of(context);
        return MediaQuery(
          // Respect the user's font-size setting, within limits the layouts
          // are tested against.
          data: media.copyWith(
            textScaler: RarResponsive.clampTextScaler(media.textScaler),
          ),
          child: RarGlassSettings(
            // Blur is costly on low-end GPUs; users who ask the OS to
            // reduce motion/effects get the cheaper, non-blurred glass.
            blurEnabled: !media.disableAnimations,
            child: child!,
          ),
        );
      },
    );
  }
}
