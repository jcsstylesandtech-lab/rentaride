import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/driver_repository.dart';
import '../data/models.dart';

final supabaseProvider = Provider<SupabaseClient>((ref) => Supabase.instance.client);

final repoProvider = Provider<DriverRepository>((ref) => DriverRepository(ref.watch(supabaseProvider)));

/// Emits on sign-in / sign-out; value is the signed-in user id or null.
final sessionProvider = StreamProvider<String?>((ref) async* {
  final auth = ref.watch(supabaseProvider).auth;
  yield auth.currentUser?.id;
  await for (final s in auth.onAuthStateChange) {
    yield s.session?.user.id;
  }
});

/// Everything the onboarding / home screens need about this driver.
class DriverState {
  const DriverState({required this.profile, required this.driver, required this.vehicles, required this.documents});
  final Profile? profile;
  final Driver? driver;
  final List<Vehicle> vehicles;
  final List<DriverDocument> documents;

  bool get isDriverAccount => profile?.role == 'driver';
  bool get approved => driver?.status == DriverStatus.approved;

  /// Latest upload per document type.
  Map<DocumentType, DriverDocument> get latestDocs {
    final m = <DocumentType, DriverDocument>{};
    for (final d in documents) {
      final cur = m[d.type];
      if (cur == null || d.createdAt.isAfter(cur.createdAt)) m[d.type] = d;
    }
    return m;
  }

  bool get docsComplete => DocumentType.values
      .where((t) => t.required)
      .every((t) => latestDocs[t] != null && latestDocs[t]!.review != 'rejected');
}

final driverStateProvider = FutureProvider<DriverState>((ref) async {
  final uid = ref.watch(sessionProvider).value;
  if (uid == null) return const DriverState(profile: null, driver: null, vehicles: [], documents: []);
  final repo = ref.watch(repoProvider);
  final results = await Future.wait([repo.myProfile(), repo.myDriver(), repo.myVehicles(), repo.myDocuments()]);
  return DriverState(
    profile: results[0] as Profile?,
    driver: results[1] as Driver?,
    vehicles: results[2] as List<Vehicle>,
    documents: results[3] as List<DriverDocument>,
  );
});
