import 'package:flutter/material.dart';
import 'package:rar_design_system/rar_design_system.dart';

/// Development-only preview of the skeleton loading style, in the light
/// (in-app) and dark (glass) themes. Registered only in non-production
/// builds; open `/dev/loading-states`.
///
/// "Simulate network" replays a load with a realistic delay so the
/// skeleton → content transition can be reviewed.
class LoadingStatesPreviewScreen extends StatefulWidget {
  const LoadingStatesPreviewScreen({super.key});

  @override
  State<LoadingStatesPreviewScreen> createState() =>
      _LoadingStatesPreviewScreenState();
}

class _LoadingStatesPreviewScreenState
    extends State<LoadingStatesPreviewScreen> {
  bool _loading = true;
  bool _dark = false;
  int _loadId = 0;

  Future<void> _simulateLoad() async {
    final id = ++_loadId;
    setState(() => _loading = true);
    await Future<void>.delayed(const Duration(milliseconds: 2200));
    if (mounted && id == _loadId) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = _dark ? RarTheme.dark() : RarTheme.light();
    final fg = _dark ? RarColors.white : RarColors.navy;

    return Theme(
      data: theme,
      child: Scaffold(
        appBar: AppBar(title: const Text('Loading states')),
        body: RarContentWidth(
          child: ListView(
            padding: const EdgeInsets.all(RarSpacing.gutter),
            children: [
              Wrap(
                spacing: RarSpacing.sm,
                runSpacing: RarSpacing.sm,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  FilterChip(
                    label: const Text('Loading'),
                    selected: _loading,
                    onSelected: (v) => setState(() {
                      _loadId++;
                      _loading = v;
                    }),
                  ),
                  FilterChip(
                    label: const Text('Dark'),
                    selected: _dark,
                    onSelected: (v) => setState(() => _dark = v),
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Simulate network'),
                    onPressed: _simulateLoad,
                  ),
                ],
              ),
              const SizedBox(height: RarSpacing.xxl),
              _SectionTitle('Driver offers', color: fg),
              RarSkeletonSwitcher(
                isLoading: _loading,
                skeleton: const SkeletonList(itemCount: 3),
                child: const _OffersList(),
              ),
              const SizedBox(height: RarSpacing.xxl),
              _SectionTitle('Recent trips', color: fg),
              RarSkeletonSwitcher(
                isLoading: _loading,
                skeleton: const RarShimmer(
                  child: Column(
                    children: [
                      SkeletonPostCard(),
                      SizedBox(height: RarSpacing.md),
                      SkeletonPostCard(),
                    ],
                  ),
                ),
                child: const _TripsList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text, {required this.color});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: RarSpacing.md),
    child: Text(text, style: RarTypography.title.copyWith(color: color)),
  );
}

// Sample content shown once "loaded" — illustrative data only.
class _OffersList extends StatelessWidget {
  const _OffersList();

  static const _offers = [
    ('Ibrahim Musa', 'Toyota Corolla · 4.9 ★ · 3 min', '₦2,800'),
    ('Chinedu Okafor', 'Honda Accord · 4.8 ★ · 5 min', '₦3,000'),
    ('Aisha Bello', 'Toyota Camry · 4.9 ★ · 6 min', '₦3,200'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final (i, (name, detail, fare)) in _offers.indexed) ...[
          if (i > 0) const SizedBox(height: RarSpacing.md),
          SkeletonCard(
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: RarColors.royal,
                  child: Text(
                    name[0],
                    style: RarTypography.titleSmall.copyWith(
                      color: RarColors.white,
                    ),
                  ),
                ),
                const SizedBox(width: RarSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: RarTypography.titleSmall),
                      Text(
                        detail,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Text(
                  fare,
                  style: RarTypography.titleSmall.copyWith(
                    color: RarColors.royal,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _TripsList extends StatelessWidget {
  const _TripsList();

  static const _trips = [
    ('Wuse, Abuja → Jabi Lake Mall', 'Yesterday · 10.4 km · ₦2,800'),
    ('Maitama → Nnamdi Azikiwe Airport', 'Mon · 38 km · ₦9,500'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final (i, (route, detail)) in _trips.indexed) ...[
          if (i > 0) const SizedBox(height: RarSpacing.md),
          SkeletonCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const IconTile(icon: Icons.route_rounded, size: 52),
                    const SizedBox(width: RarSpacing.md),
                    Expanded(
                      child: Text(route, style: RarTypography.titleSmall),
                    ),
                  ],
                ),
                const SizedBox(height: RarSpacing.lg),
                Text(detail, style: RarTypography.body),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
