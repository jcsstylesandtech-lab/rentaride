import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rar_design_system/rar_design_system.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config.dart';
import '../widgets/common.dart';

/// Switches staff set on the dashboard's App control page, as the driver app uses them.
class DriverAppSettings {
  const DriverAppSettings({this.maintenance = false, this.maintenanceMessage = '', this.announcement});
  final bool maintenance;
  final String maintenanceMessage;
  final String? announcement;

  factory DriverAppSettings.fromRow(Map<String, dynamic> r) {
    final a = (r['driver_announcement'] as String?)?.trim();
    return DriverAppSettings(
      maintenance: r['driver_maintenance'] as bool? ?? false,
      maintenanceMessage: (r['maintenance_message'] as String?) ?? '',
      announcement: (a == null || a.isEmpty) ? null : a,
    );
  }
}

/// Live; if it can't be loaded the app carries on as normal.
final appSettingsProvider = StreamProvider<DriverAppSettings>((ref) {
  if (!AppConfig.isConfigured) return Stream.value(const DriverAppSettings());
  return Supabase.instance.client
      .from('app_settings')
      .stream(primaryKey: ['id'])
      .map((rows) => rows.isEmpty ? const DriverAppSettings() : DriverAppSettings.fromRow(rows.first))
      .handleError((Object _) {});
});

class DriverNotification {
  const DriverNotification({required this.id, required this.title, required this.body, required this.createdAt,
      required this.read});
  final String id;
  final String title;
  final String body;
  final DateTime createdAt;
  final bool read;

  factory DriverNotification.fromRow(Map<String, dynamic> r) => DriverNotification(
        id: r['id'] as String,
        title: r['title'] as String,
        body: (r['body'] as String?) ?? '',
        createdAt: DateTime.parse(r['created_at'] as String),
        read: r['read_at'] != null,
      );
}

final _userIdProvider = StreamProvider<String?>((ref) async* {
  if (!AppConfig.isConfigured) {
    yield null;
    return;
  }
  final auth = Supabase.instance.client.auth;
  yield auth.currentUser?.id;
  yield* auth.onAuthStateChange.map((s) => s.session?.user.id);
});

/// The driver's latest notifications, newest first, live.
final notificationsProvider = StreamProvider<List<DriverNotification>>((ref) {
  final uid = ref.watch(_userIdProvider).value;
  if (uid == null) return Stream.value(const []);
  return Supabase.instance.client
      .from('notifications')
      .stream(primaryKey: ['id'])
      .eq('user_id', uid)
      .order('created_at')
      .limit(50)
      .map((rows) => rows.map(DriverNotification.fromRow).toList())
      .handleError((Object _) {});
});

/// Wraps the app: maintenance screen, announcement banner, and a pop-up when
/// a notification arrives while the app is open.
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
  DriverNotification? _toast;
  Timer? _toastTimer;

  @override
  void dispose() {
    _toastTimer?.cancel();
    super.dispose();
  }

  void _maybeToast(List<DriverNotification> list) {
    for (final n in list) {
      if (n.read || _shown.contains(n.id) || n.createdAt.isBefore(_openedAt.subtract(const Duration(seconds: 5)))) {
        continue;
      }
      _shown.add(n.id);
      _toastTimer?.cancel();
      setState(() => _toast = n);
      _toastTimer = Timer(const Duration(seconds: 5), () { if (mounted) setState(() => _toast = null); });
      break;
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(notificationsProvider, (_, next) => _maybeToast(next.value ?? const []));
    final settings = ref.watch(appSettingsProvider).value ?? const DriverAppSettings();
    if (settings.maintenance) {
      return MessageScreen(
        icon: Icons.construction_rounded,
        title: 'Back soon',
        body: settings.maintenanceMessage.isEmpty
            ? 'The driver app is being updated. Please check back shortly.'
            : settings.maintenanceMessage,
      );
    }

    final media = MediaQuery.of(context);
    final banner = settings.announcement;
    Widget content = widget.child;
    if (banner != null && banner != _dismissedBanner) {
      content = Column(children: [
        Material(
          color: RarColors.royal,
          child: Padding(
            padding: EdgeInsets.fromLTRB(RarSpacing.md, media.padding.top + 6, 4, 6),
            child: Row(children: [
              const Icon(Icons.campaign_rounded, color: RarColors.white, size: 20),
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
              color: RarColors.navy900,
              shape: const RoundedRectangleBorder(borderRadius: RarRadius.card, side: BorderSide(color: RarColors.cyan)),
              child: InkWell(
                borderRadius: RarRadius.card,
                onTap: () => setState(() => _toast = null),
                child: Padding(
                  padding: const EdgeInsets.all(RarSpacing.md),
                  child: Row(children: [
                    const Icon(Icons.notifications_active_rounded, color: RarColors.cyan),
                    const SizedBox(width: RarSpacing.md),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                      Text(toast.title, style: RarTypography.titleSmall.copyWith(color: RarColors.white)),
                      if (toast.body.isNotEmpty)
                        Text(toast.body, maxLines: 2, overflow: TextOverflow.ellipsis,
                            style: RarTypography.bodySmall.copyWith(color: RarColors.textOnDarkSecondary)),
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

/// Inbox of everything staff and trips have sent this driver.
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    if (AppConfig.isConfigured) {
      Supabase.instance.client.rpc('mark_notifications_read').catchError((Object _) => null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(notificationsProvider).value ?? const [];
    return DriverScaffold(
      child: ListView(children: [
        const SizedBox(height: RarSpacing.md),
        Row(children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            tooltip: 'Back',
            icon: const Icon(Icons.arrow_back_rounded, color: RarColors.white),
          ),
          Text('Notifications', style: RarTypography.title.copyWith(color: RarColors.white)),
        ]),
        const SizedBox(height: RarSpacing.md),
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: RarSpacing.xxl),
            child: Center(child: Text('Nothing yet', style: onDarkMuted)),
          ),
        for (final n in items)
          Padding(
            padding: const EdgeInsets.only(bottom: RarSpacing.sm),
            child: Panel(
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(n.read ? Icons.notifications_none_rounded : Icons.notifications_active_rounded, color: RarColors.cyan),
                const SizedBox(width: RarSpacing.md),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(n.title, style: RarTypography.titleSmall.copyWith(color: RarColors.white)),
                  if (n.body.isNotEmpty) Text(n.body, style: onDarkMuted),
                  Text(_when(n.createdAt), style: RarTypography.caption.copyWith(color: RarColors.textOnDarkMuted)),
                ])),
              ]),
            ),
          ),
      ]),
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
