import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rar_design_system/rar_design_system.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/app_config.dart';

/// Switches staff set on the dashboard's App control page (one row).
class AppSettings {
  const AppSettings({this.ridesEnabled = true, this.dispatchEnabled = true, this.deliveryEnabled = true,
      this.maintenance = false, this.maintenanceMessage = '', this.announcement});
  final bool ridesEnabled;
  final bool dispatchEnabled;
  final bool deliveryEnabled;
  final bool maintenance;
  final String maintenanceMessage;
  final String? announcement;

  bool get anyDeliveryEnabled => dispatchEnabled || deliveryEnabled;
  bool serviceEnabled(String service) => switch (service) {
        'dispatch' => dispatchEnabled,
        'delivery' => deliveryEnabled,
        _ => ridesEnabled,
      };

  factory AppSettings.fromRow(Map<String, dynamic> r) => AppSettings(
        ridesEnabled: r['rides_enabled'] as bool? ?? true,
        dispatchEnabled: r['dispatch_enabled'] as bool? ?? true,
        deliveryEnabled: r['delivery_enabled'] as bool? ?? true,
        maintenance: r['passenger_maintenance'] as bool? ?? false,
        maintenanceMessage: (r['maintenance_message'] as String?) ?? '',
        announcement: (r['passenger_announcement'] as String?)?.trim().isEmpty == true
            ? null
            : r['passenger_announcement'] as String?,
      );
}

/// Live app settings. If they can't be loaded the app keeps working as normal.
final appSettingsProvider = StreamProvider<AppSettings>((ref) {
  if (!AppConfig.hasBackend) return Stream.value(const AppSettings());
  return Supabase.instance.client
      .from('app_settings')
      .stream(primaryKey: ['id'])
      .map((rows) => rows.isEmpty ? const AppSettings() : AppSettings.fromRow(rows.first))
      .handleError((Object _) {});
});

class AppNotification {
  const AppNotification({required this.id, required this.title, required this.body, required this.createdAt,
      required this.read});
  final String id;
  final String title;
  final String body;
  final DateTime createdAt;
  final bool read;

  factory AppNotification.fromRow(Map<String, dynamic> r) => AppNotification(
        id: r['id'] as String,
        title: r['title'] as String,
        body: (r['body'] as String?) ?? '',
        createdAt: DateTime.parse(r['created_at'] as String),
        read: r['read_at'] != null,
      );
}

final _userIdProvider = StreamProvider<String?>((ref) async* {
  if (!AppConfig.hasBackend) {
    yield null;
    return;
  }
  final auth = Supabase.instance.client.auth;
  yield auth.currentUser?.id;
  yield* auth.onAuthStateChange.map((s) => s.session?.user.id);
});

/// The signed-in person's latest notifications, newest first, live.
final notificationsProvider = StreamProvider<List<AppNotification>>((ref) {
  final uid = ref.watch(_userIdProvider).value;
  if (uid == null) return Stream.value(const []);
  return Supabase.instance.client
      .from('notifications')
      .stream(primaryKey: ['id'])
      .eq('user_id', uid)
      .order('created_at')
      .limit(50)
      .map((rows) => rows.map(AppNotification.fromRow).toList())
      .handleError((Object _) {});
});

Future<void> markNotificationsRead() async {
  if (!AppConfig.hasBackend) return;
  try {
    await Supabase.instance.client.rpc('mark_notifications_read');
  } catch (_) {/* they stay unread; harmless */}
}

/// Wraps every screen: maintenance screen, announcement banner, and a short
/// pop-up when a new notification arrives while the app is open.
class AppControlShell extends ConsumerStatefulWidget {
  const AppControlShell({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<AppControlShell> createState() => _AppControlShellState();
}

class _AppControlShellState extends ConsumerState<AppControlShell> {
  final _openedAt = DateTime.now();
  final _shown = <String>{};
  String? _dismissedBanner;
  AppNotification? _toast;
  Timer? _toastTimer;

  @override
  void dispose() {
    _toastTimer?.cancel();
    super.dispose();
  }

  void _maybeToast(List<AppNotification> list) {
    for (final n in list) {
      if (n.read || _shown.contains(n.id) || n.createdAt.isBefore(_openedAt.subtract(const Duration(seconds: 5)))) {
        continue;
      }
      _shown.add(n.id);
      _toastTimer?.cancel();
      setState(() => _toast = n);
      _toastTimer = Timer(const Duration(seconds: 5), () { if (mounted) setState(() => _toast = null); });
      break; // newest first; one at a time
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(notificationsProvider, (_, next) => _maybeToast(next.value ?? const []));
    final settings = ref.watch(appSettingsProvider).value ?? const AppSettings();
    if (settings.maintenance) return _Maintenance(message: settings.maintenanceMessage);

    final media = MediaQuery.of(context);
    final banner = settings.announcement;
    Widget content = widget.child;
    if (banner != null && banner != _dismissedBanner) {
      content = Column(children: [
        Material(
          color: RarColors.navy,
          child: Padding(
            padding: EdgeInsets.fromLTRB(RarSpacing.md, media.padding.top + 6, 4, 6),
            child: Row(children: [
              const Icon(Icons.campaign_rounded, color: RarColors.cyan, size: 20),
              const SizedBox(width: RarSpacing.sm),
              Expanded(child: Text(banner, style: RarTypography.bodySmall.copyWith(color: RarColors.white))),
              IconButton(
                tooltip: 'Hide announcement',
                onPressed: () => setState(() => _dismissedBanner = banner),
                icon: const Icon(Icons.close_rounded, color: RarColors.white, size: 18),
              ),
            ]),
          ),
        ),
        Expanded(child: MediaQuery.removePadding(context: context, removeTop: true, child: widget.child)),
      ]);
    }

    final toast = _toast;
    return Stack(children: [
      Positioned.fill(child: content),
      if (toast != null)
        Positioned(
          top: media.padding.top + 8,
          left: 12,
          right: 12,
          child: Semantics(
            liveRegion: true,
            child: Material(
              elevation: 8,
              color: RarColors.white,
              borderRadius: RarRadius.card,
              child: InkWell(
                borderRadius: RarRadius.card,
                onTap: () => setState(() => _toast = null),
                child: Padding(
                  padding: const EdgeInsets.all(RarSpacing.md),
                  child: Row(children: [
                    const Icon(Icons.notifications_active_rounded, color: RarColors.royal),
                    const SizedBox(width: RarSpacing.md),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                      Text(toast.title, style: RarTypography.titleSmall.copyWith(color: RarColors.navy)),
                      if (toast.body.isNotEmpty)
                        Text(toast.body, maxLines: 2, overflow: TextOverflow.ellipsis,
                            style: RarTypography.bodySmall.copyWith(color: RarColors.textSecondary)),
                    ])),
                  ]),
                ),
              ),
            ),
          ),
        ),
    ]);
  }
}

class _Maintenance extends StatelessWidget {
  const _Maintenance({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Material(
        color: RarColors.background,
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(RarSpacing.xl),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.construction_rounded, size: 56, color: RarColors.royal),
                const SizedBox(height: RarSpacing.lg),
                Text('Back soon', textAlign: TextAlign.center, style: RarTypography.headline.copyWith(color: RarColors.navy)),
                const SizedBox(height: RarSpacing.sm),
                Text(message.isEmpty ? 'Rent A Ride is being updated. Please check back shortly.' : message,
                    textAlign: TextAlign.center, style: RarTypography.body.copyWith(color: RarColors.textSecondary)),
              ]),
            ),
          ),
        ),
      );
}

/// Inbox: everything staff and trips have sent this person.
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    markNotificationsRead();
  }

  @override
  Widget build(BuildContext context) {
    final list = ref.watch(notificationsProvider);
    return Theme(
      data: RarTheme.light(),
      child: Scaffold(
        backgroundColor: RarColors.background,
        appBar: AppBar(title: const Text('Notifications')),
        body: list.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => const Center(child: Text("Couldn't load notifications.")),
          data: (items) => items.isEmpty
              ? Center(child: Text('Nothing yet', style: RarTypography.body.copyWith(color: RarColors.textSecondary)))
              : ListView.separated(
                  padding: const EdgeInsets.all(RarSpacing.md),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: RarSpacing.sm),
                  itemBuilder: (_, i) {
                    final n = items[i];
                    return Material(
                      color: RarColors.white,
                      borderRadius: RarRadius.card,
                      child: ListTile(
                        leading: Icon(n.read ? Icons.notifications_none_rounded : Icons.notifications_active_rounded,
                            color: RarColors.royal),
                        title: Text(n.title, style: RarTypography.titleSmall.copyWith(color: RarColors.navy)),
                        subtitle: Text([if (n.body.isNotEmpty) n.body, _when(n.createdAt)].join('\n'),
                            style: RarTypography.bodySmall.copyWith(color: RarColors.textSecondary)),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}

String _when(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return 'Just now';
  if (d.inHours < 1) return '${d.inMinutes} min ago';
  if (d.inDays < 1) return '${d.inHours} h ago';
  final l = t.toLocal();
  return '${l.day}/${l.month}/${l.year}';
}
