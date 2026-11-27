import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rar_design_system/rar_design_system.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/config/app_config.dart';
import '../../../app_control/app_control.dart';
import '../../../rides/delivery_sheet.dart';
import '../../../rides/ride_options_sheet.dart';

import '../../../../app/router/app_routes.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../map/dashboard_map.dart';
import '../../../map/map_data.dart';
import '../../../profile/profile_photo.dart';
import '../controllers/home_providers.dart';
import '../screens/place_search_screen.dart';

/// Map, pickup, "Where to?", saved places and recent destinations.
class HomeTab extends ConsumerStatefulWidget {
  const HomeTab({super.key, required this.onOpenProfile});

  final VoidCallback onOpenProfile;

  @override
  ConsumerState<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends ConsumerState<HomeTab> {
  final _mapKey = GlobalKey<DashboardMapState>();

  Future<void> _search({SavedPlaceSlot? saveAs}) async {
    final place = await context.push<Place>(
      AppRoutes.placeSearch,
      extra: PlaceSearchArgs(saveAs: saveAs),
    );
    if (place == null || !mounted) return;
    if (saveAs != null) {
      await savePlace(ref, saveAs, place);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${saveAs == SavedPlaceSlot.home ? 'Home' : 'Work'} '
            'set to ${place.name}.',
          ),
        ),
      );
    } else {
      await ref.read(destinationProvider.notifier).choose(place);
    }
  }

  void _openNotifications() {
    final user = ref.read(authControllerProvider);
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Notifications', style: RarTypography.headline),
              const SizedBox(height: RarSpacing.lg),
              _Notice(
                icon: Icons.celebration_rounded,
                title: 'Welcome to Rent A Ride, ${user?.firstName ?? ''}',
                body:
                    'Choose a fixed fare or name your own price on every '
                    'ride.',
              ),
              if (user != null && !user.hasEmergencyContact)
                const _Notice(
                  icon: Icons.sos_rounded,
                  title: 'Add an emergency contact',
                  body:
                      'We alert them only if you press SOS during a trip. '
                      'Add one from Profile.',
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final user = ref.watch(authControllerProvider);
    final pickup = ref.watch(currentLocationProvider);
    final drivers = ref.watch(nearbyDriversProvider).value ?? const [];
    final destination = ref.watch(destinationProvider);
    const headerHeight = 76.0;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final h = constraints.maxHeight;
          // Fixed panel height keeps the map's visible area predictable.
          final panelHeight = (h * 0.46).clamp(250.0, 420.0);
          final mapTop = media.padding.top + headerHeight + 8;
          // Zoom buttons only when there's room between header and panel.
          final showZoom = h - panelHeight - mapTop > 230;

          return Stack(
            children: [
              Positioned.fill(
                child: pickup.when(
                  data: (p) => DashboardMap(
                    key: _mapKey,
                    origin: p.location,
                    drivers: drivers,
                    destination: destination,
                    places: DemoPlacesRepository.all,
                    fitPadding: EdgeInsets.only(
                      top: media.padding.top + headerHeight + 24,
                      bottom: panelHeight - 8,
                      left: 24,
                      right: 24,
                    ),
                  ),
                  loading: () => const RarShimmer(
                    child: SkeletonBox(
                      height: double.infinity,
                      borderRadius: BorderRadius.zero,
                    ),
                  ),
                  error: (e, _) => _MapError(
                    onRetry: () => ref.invalidate(currentLocationProvider),
                  ),
                ),
              ),

              // Header: greeting, notifications, avatar.
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  bottom: false,
                  child: RarContentWidth(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: GlassContainer(
                        tone: GlassTone.light,
                        padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Hello, ${user?.firstName ?? 'there'}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: RarTypography.title,
                                  ),
                                  Text(
                                    'Where are you going today?',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: RarTypography.bodySmall.copyWith(
                                      color: RarColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: 'Notifications',
                              onPressed: _openNotifications,
                              icon: const Badge(
                                smallSize: 8,
                                backgroundColor: RarColors.danger,
                                child: Icon(
                                  Icons.notifications_none_rounded,
                                  color: RarColors.navy,
                                ),
                              ),
                            ),
                            Semantics(
                              button: true,
                              label: 'Open profile',
                              child: GestureDetector(
                                onTap: widget.onOpenProfile,
                                child: RarAvatar(
                                  radius: 20,
                                  name: user?.firstName ?? '',
                                  imageUrl: ref.watch(profilePhotoProvider).value,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Drivers-nearby chip.
              if (drivers.isNotEmpty)
                Positioned(
                  top: media.padding.top + headerHeight + 18,
                  left: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: RarColors.white,
                      borderRadius: RarRadius.pillShape,
                      boxShadow: RarShadows.soft,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: RarColors.success,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${drivers.length} drivers nearby',
                          style: RarTypography.caption.copyWith(
                            color: RarColors.navy,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Map controls, just above the panel.
              Positioned(
                right: 16,
                bottom: panelHeight + 12,
                child: Column(
                  children: [
                    if (showZoom) ...[
                      _MapButton(
                        icon: Icons.add_rounded,
                        tooltip: 'Zoom in',
                        onPressed: () => _mapKey.currentState?.zoomBy(1.6),
                      ),
                      const SizedBox(height: 8),
                      _MapButton(
                        icon: Icons.remove_rounded,
                        tooltip: 'Zoom out',
                        onPressed: () => _mapKey.currentState?.zoomBy(1 / 1.6),
                      ),
                      const SizedBox(height: 8),
                    ],
                    _MapButton(
                      icon: Icons.my_location_rounded,
                      tooltip: 'Back to my location',
                      onPressed: () => _mapKey.currentState?.recenter(),
                    ),
                  ],
                ),
              ),

              // Bottom panel.
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: panelHeight,
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: RarResponsive.maxContentWidth,
                    ),
                    child: Container(
                      height: panelHeight,
                      decoration: const BoxDecoration(
                        color: RarColors.white,
                        borderRadius: RarRadius.sheet,
                        boxShadow: RarShadows.medium,
                      ),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                        child: destination == null
                            ? _PlanPanel(
                                pickup: pickup.value,
                                onSearch: () => _search(),
                                onSaveSlot: (slot) => _search(saveAs: slot),
                              )
                            : _TripPanel(
                                pickup: pickup.value,
                                destination: destination,
                                onChange: () => _search(),
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Handle extends StatelessWidget {
  const _Handle();

  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      width: 40,
      height: 4,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: RarColors.outlineLight,
        borderRadius: RarRadius.pillShape,
      ),
    ),
  );
}

class _PlanPanel extends ConsumerWidget {
  const _PlanPanel({
    required this.pickup,
    required this.onSearch,
    required this.onSaveSlot,
  });

  final Place? pickup;
  final VoidCallback onSearch;
  final ValueChanged<SavedPlaceSlot> onSaveSlot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saved = ref.watch(savedPlacesProvider);
    final recent = ref.watch(recentDestinationsProvider);

    void choose(Place p) => ref.read(destinationProvider.notifier).choose(p);

    Widget slot(SavedPlaceSlot s, IconData icon, String label) {
      final place = saved.value?[s];
      return Expanded(
        child: _Shortcut(
          icon: icon,
          title: label,
          subtitle: place?.name ?? 'Add',
          onTap: saved.isLoading
              ? null
              : () => place == null ? onSaveSlot(s) : choose(place),
          onLongPress: place == null ? null : () => onSaveSlot(s),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Handle(),
        _Stop(
          icon: Icons.radio_button_checked,
          color: RarColors.royal,
          label: 'Pickup',
          title: pickup?.name ?? 'Finding your location…',
          subtitle: pickup?.address ?? '',
        ),
        const SizedBox(height: RarSpacing.md),
        Semantics(
          button: true,
          label: 'Where to? Search for a destination',
          excludeSemantics: true,
          child: Material(
            color: RarColors.background,
            borderRadius: RarRadius.card,
            child: InkWell(
              borderRadius: RarRadius.card,
              onTap: onSearch,
              child: Container(
                height: 52,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  borderRadius: RarRadius.card,
                  border: Border.all(color: RarColors.outlineLight),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.search_rounded, color: RarColors.navy),
                    const SizedBox(width: 12),
                    Text(
                      'Where to?',
                      style: RarTypography.body.copyWith(
                        fontSize: 16,
                        color: RarColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: RarSpacing.md),
        Row(
          children: [
            slot(SavedPlaceSlot.home, Icons.home_rounded, 'Home'),
            const SizedBox(width: 10),
            slot(SavedPlaceSlot.work, Icons.work_rounded, 'Work'),
          ],
        ),
        const SizedBox(height: RarSpacing.lg),
        Text('Recent', style: RarTypography.titleSmall),
        const SizedBox(height: RarSpacing.sm),
        RarSkeletonSwitcher(
          isLoading: recent.isLoading && !recent.hasValue,
          skeleton: const RarShimmer(
            child: Column(
              children: [
                SkeletonListTile(avatarSize: 36, trailing: false),
                SizedBox(height: 14),
                SkeletonListTile(avatarSize: 36, trailing: false),
              ],
            ),
          ),
          child: switch (recent) {
            AsyncData(:final value) when value.isEmpty => Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Places you ride to will show here.',
                style: RarTypography.bodySmall.copyWith(
                  color: RarColors.textSecondary,
                ),
              ),
            ),
            AsyncError() => TextButton.icon(
              onPressed: () => ref.invalidate(recentDestinationsProvider),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text("Couldn't load recent places. Try again"),
            ),
            _ => Column(
              children: [
                for (final p in (recent.value ?? const <Place>[]).take(3))
                  PlaceTile(
                    place: p,
                    from: pickup?.location,
                    icon: Icons.history_rounded,
                    onTap: () => choose(p),
                  ),
              ],
            ),
          },
        ),
      ],
    );
  }
}

class _TripPanel extends ConsumerWidget {
  const _TripPanel({
    required this.pickup,
    required this.destination,
    required this.onChange,
  });

  final Place? pickup;
  final Place destination;
  final VoidCallback onChange;

  Future<void> _directions(BuildContext context) async {
    final from = pickup?.location;
    if (from == null) return;
    final opened = await launchUrl(
      Geo.googleMapsDirections(from, destination.location),
      mode: LaunchMode.externalApplication,
    );
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't open Google Maps.")),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estimate = ref.watch(tripEstimateProvider);
    final control = ref.watch(appSettingsProvider).value ?? const AppSettings();
    final ready = AppConfig.hasBackend && pickup != null && estimate != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Handle(),
        Row(
          children: [
            Expanded(child: Text('Your trip', style: RarTypography.title)),
            IconButton(
              tooltip: 'Clear destination',
              onPressed: () => ref.read(destinationProvider.notifier).clear(),
              icon: const Icon(Icons.close_rounded),
            ),
          ],
        ),
        _Stop(
          icon: Icons.radio_button_checked,
          color: RarColors.royal,
          label: 'Pickup',
          title: pickup?.name ?? '',
          subtitle: pickup?.address ?? '',
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: Container(
            width: 2,
            height: 14,
            margin: const EdgeInsets.only(left: 9),
            color: RarColors.outlineLight,
          ),
        ),
        _Stop(
          icon: Icons.location_on_rounded,
          color: RarColors.danger,
          label: 'Destination',
          title: destination.name,
          subtitle: destination.address,
        ),
        if (estimate != null) ...[
          const SizedBox(height: RarSpacing.lg),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: RarColors.background,
              borderRadius: RarRadius.card,
            ),
            child: Row(
              children: [
                _Metric(
                  label: 'Distance',
                  value: '${estimate.distanceKm.toStringAsFixed(1)} km',
                ),
                _Metric(label: 'Time', value: '~${estimate.durationMin} min'),
                _Metric(
                  label: 'Economy from',
                  value: formatNaira(estimate.economyFareNaira),
                  highlight: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Estimate. You can also name your own price on the next step.',
            style: RarTypography.caption.copyWith(color: RarColors.textMuted),
          ),
        ],
        const SizedBox(height: RarSpacing.lg),
        RarButton.primary(
          key: const ValueKey('choose-ride'),
          label: 'Choose a ride',
          trailingIcon: Icons.arrow_forward_rounded,
          onPressed: ready && control.ridesEnabled
              ? () => showRideOptions(context, pickup: pickup!, dropoff: destination, estimate: estimate)
              : null,
          semanticLabel: AppConfig.hasBackend ? null : 'Choose a ride. Needs the live server.',
        ),
        const SizedBox(height: RarSpacing.sm),
        RarButton.outline(
          key: const ValueKey('send-package'),
          label: 'Send a package',
          leadingIcon: Icons.inventory_2_rounded,
          onPressed: ready && control.anyDeliveryEnabled
              ? () => showDeliveryOptions(context, pickup: pickup!, dropoff: destination, estimate: estimate)
              : null,
        ),
        if (!control.ridesEnabled || !control.anyDeliveryEnabled) ...[
          const SizedBox(height: 6),
          Text(
            '${[
              if (!control.ridesEnabled) 'Ride booking',
              if (!control.anyDeliveryEnabled) 'Package delivery',
            ].join(' and ')} is paused right now. Please try again later.',
            textAlign: TextAlign.center,
            style: RarTypography.caption.copyWith(color: RarColors.textMuted),
          ),
        ],
        if (!AppConfig.hasBackend) ...[
          const SizedBox(height: 6),
          Text(
            'Booking needs the live server — run with env/dev.json.',
            textAlign: TextAlign.center,
            style: RarTypography.caption.copyWith(color: RarColors.textMuted),
          ),
        ],
        const SizedBox(height: RarSpacing.sm),
        RarButton.outline(
          key: const ValueKey('directions-google-maps'),
          label: 'Directions in Google Maps',
          leadingIcon: Icons.map_rounded,
          onPressed: () => _directions(context),
        ),
        const SizedBox(height: RarSpacing.sm),
        RarButton.outline(label: 'Change destination', onPressed: onChange),
      ],
    );
  }
}

class _Stop extends StatelessWidget {
  const _Stop({
    required this.icon,
    required this.color,
    required this.label,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, color: color, size: 20),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: RarTypography.caption.copyWith(color: RarColors.textMuted),
            ),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: RarTypography.titleSmall,
            ),
            if (subtitle.isNotEmpty)
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: RarTypography.bodySmall.copyWith(
                  color: RarColors.textSecondary,
                ),
              ),
          ],
        ),
      ),
    ],
  );
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    this.highlight = false,
  });
  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: RarTypography.caption.copyWith(color: RarColors.textMuted),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: RarTypography.titleSmall.copyWith(
              color: highlight ? RarColors.royal : RarColors.navy,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    ),
  );
}

class _Shortcut extends StatelessWidget {
  const _Shortcut({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.onLongPress,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final isAdd = subtitle == 'Add';
    return Material(
      color: RarColors.background,
      borderRadius: RarRadius.card,
      child: InkWell(
        borderRadius: RarRadius.card,
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              IconTile(icon: icon, size: 36),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: RarTypography.titleSmall.copyWith(fontSize: 14),
                    ),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: RarTypography.bodySmall.copyWith(
                        color: isAdd
                            ? RarColors.royal
                            : RarColors.textSecondary,
                        fontWeight: isAdd ? FontWeight.w600 : FontWeight.w400,
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

/// A place in a list: icon, name, address and distance from [from].
class PlaceTile extends StatelessWidget {
  const PlaceTile({
    super.key,
    required this.place,
    required this.onTap,
    this.from,
    this.icon = Icons.location_on_outlined,
  });

  final Place place;
  final GeoPoint? from;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final km = from == null
        ? null
        : Geo.distanceM(from!, place.location) / 1000;
    return InkWell(
      onTap: onTap,
      borderRadius: RarRadius.card,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                color: RarColors.background,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: RarColors.navy, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    place.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: RarTypography.titleSmall.copyWith(fontSize: 14),
                  ),
                  Text(
                    place.address,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: RarTypography.bodySmall.copyWith(
                      color: RarColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (km != null) ...[
              const SizedBox(width: 8),
              Text(
                '${km.toStringAsFixed(1)} km',
                style: RarTypography.caption.copyWith(
                  color: RarColors.textMuted,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MapButton extends StatelessWidget {
  const _MapButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Material(
    color: RarColors.white,
    shape: const CircleBorder(),
    elevation: 3,
    shadowColor: const Color(0x33061B49),
    child: IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, color: RarColors.navy),
    ),
  );
}

class _MapError extends StatelessWidget {
  const _MapError({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: RarColors.background,
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.location_off_rounded,
              size: 40,
              color: RarColors.textMuted,
            ),
            const SizedBox(height: 12),
            Text(
              "We couldn't find your location. Check that location is "
              'on, then try again.',
              textAlign: TextAlign.center,
              style: RarTypography.body,
            ),
            TextButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    ),
  );
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.title, required this.body});
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IconTile(icon: icon, size: 40),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: RarTypography.titleSmall),
              Text(
                body,
                style: RarTypography.bodySmall.copyWith(
                  color: RarColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
