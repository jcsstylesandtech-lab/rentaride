/// Kobo (integer) → "₦2,000".
String naira(num? kobo) {
  final n = ((kobo ?? 0) / 100).round();
  final s = n.abs().toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
  return '${n < 0 ? '-' : ''}₦$s';
}

String km(num? meters) => meters == null ? '—' : '${(meters / 1000).toStringAsFixed(1)} km';

String titleCase(String s) => s
    .replaceAll('_', ' ')
    .split(' ')
    .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
    .join(' ');

String timeAgo(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return 'just now';
  if (d.inHours < 1) return '${d.inMinutes} min ago';
  if (d.inDays < 1) return '${d.inHours} h ago';
  return '${d.inDays} d ago';
}

/// Friendly text for errors coming back from Supabase.
String friendlyError(Object e) {
  final s = e.toString();
  final m = RegExp(r'message: ([^,}]+)').firstMatch(s);
  final msg = (m?.group(1) ?? s).replaceFirst(RegExp(r'^(Exception|AuthException|PostgrestException)[:(]\s*'), '');
  if (msg.contains('Invalid login credentials')) return 'Wrong email or password.';
  if (msg.contains('Email not confirmed')) return 'Confirm your email first — check your inbox.';
  final lower = msg.toLowerCase();
  if (lower.contains('expired') || (lower.contains('invalid') && lower.contains('token'))) {
    return 'That code is wrong or has expired. Check it, or send a new code.';
  }
  if (lower.contains('should be different')) return 'Choose a password different from your old one.';
  if (lower.contains('rate limit') || lower.contains('security purposes')) {
    return 'Too many attempts. Wait a minute and try again.';
  }
  if (msg.contains('SocketException') || msg.contains('Failed host lookup')) {
    return 'No internet connection. Check your network and try again.';
  }
  return msg.length > 160 ? '${msg.substring(0, 160)}…' : msg;
}
