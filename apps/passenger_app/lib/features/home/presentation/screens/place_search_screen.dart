import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rar_design_system/rar_design_system.dart';

import '../../../map/map_data.dart';
import '../controllers/home_providers.dart';
import '../widgets/home_tab.dart';

/// What the search is for: a destination, or setting a saved place.
class PlaceSearchArgs {
  const PlaceSearchArgs({this.saveAs});
  final SavedPlaceSlot? saveAs;
}

/// Destination search. Pops with the chosen [Place].
class PlaceSearchScreen extends ConsumerStatefulWidget {
  const PlaceSearchScreen({super.key, this.args = const PlaceSearchArgs()});

  final PlaceSearchArgs args;

  @override
  ConsumerState<PlaceSearchScreen> createState() => _PlaceSearchScreenState();
}

class _PlaceSearchScreenState extends ConsumerState<PlaceSearchScreen> {
  final _query = TextEditingController();
  Timer? _debounce;
  List<Place>? _results;
  bool _loading = true;
  String? _error;
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    _run('');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    // Wait for a pause in typing: fewer requests on slow networks.
    _debounce = Timer(const Duration(milliseconds: 250), () => _run(value));
  }

  Future<void> _run(String query) async {
    final id = ++_requestId;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await ref.read(placesRepositoryProvider).search(query);
      if (mounted && id == _requestId) {
        setState(() {
          _results = results;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted && id == _requestId) {
        setState(() {
          _loading = false;
          _error = "Couldn't search right now. Check your connection.";
        });
      }
    }
  }

  /// Search suggestions get their exact location only once picked.
  Future<void> _pick(Place place) async {
    if (!place.needsLookup) {
      context.pop(place);
      return;
    }
    setState(() => _loading = true);
    try {
      final exact = await ref.read(placesRepositoryProvider).resolve(place);
      if (mounted) context.pop(exact);
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't get that place. Check your connection and try again.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final pickup = ref.watch(currentLocationProvider).value;
    final title = switch (widget.args.saveAs) {
      SavedPlaceSlot.home => 'Set Home',
      SavedPlaceSlot.work => 'Set Work',
      null => 'Where to?',
    };
    final searching = _query.text.trim().isNotEmpty;

    return Theme(
      data: RarTheme.light(),
      child: Scaffold(
        backgroundColor: RarColors.white,
        appBar: AppBar(title: Text(title)),
        body: RarContentWidth(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: TextField(
                  key: const ValueKey('place-search-field'),
                  controller: _query,
                  autofocus: true,
                  textInputAction: TextInputAction.search,
                  onChanged: _onChanged,
                  onSubmitted: _run,
                  decoration: InputDecoration(
                    hintText: 'Search places in Abuja',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: searching
                        ? IconButton(
                            tooltip: 'Clear search',
                            onPressed: () {
                              _query.clear();
                              _run('');
                            },
                            icon: const Icon(Icons.close_rounded),
                          )
                        : null,
                  ),
                ),
              ),
              Expanded(
                child: RarSkeletonSwitcher(
                  isLoading: _loading && _results == null,
                  skeleton: Padding(
                    padding: const EdgeInsets.all(16),
                    child: RarShimmer(
                      child: Column(
                        children: [
                          for (var i = 0; i < 5; i++) ...[
                            const SkeletonListTile(
                              avatarSize: 36,
                              trailing: false,
                            ),
                            const SizedBox(height: 18),
                          ],
                        ],
                      ),
                    ),
                  ),
                  child: _buildResults(pickup, searching),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResults(Place? pickup, bool searching) {
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: RarTypography.body),
            TextButton(
              onPressed: () => _run(_query.text),
              child: const Text('Try again'),
            ),
          ],
        ),
      );
    }
    final results = _results ?? const <Place>[];
    if (results.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(
              Icons.search_off_rounded,
              size: 40,
              color: RarColors.textMuted,
            ),
            const SizedBox(height: 8),
            Text(
              'No places match "${_query.text.trim()}". '
              'Try a landmark, area or street.',
              textAlign: TextAlign.center,
              style: RarTypography.body.copyWith(
                color: RarColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        if (_loading) const LinearProgressIndicator(minHeight: 2),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            searching ? 'Results' : 'Popular in Abuja',
            style: RarTypography.titleSmall,
          ),
        ),
        for (final p in results)
          PlaceTile(
            place: p,
            from: p.needsLookup ? null : pickup?.location,
            onTap: () => _pick(p),
          ),
      ],
    );
  }
}
