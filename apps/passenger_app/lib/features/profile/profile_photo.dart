import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:rar_design_system/rar_design_system.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/app_config.dart';
import '../auth/presentation/controllers/auth_controller.dart';

/// Stores the rider's profile photo in the public `avatars` bucket
/// (`avatars/<user id>/<file>`) and its URL in `profiles.avatar_url`.
abstract interface class ProfilePhotoRepository {
  Future<String?> current();
  Future<String> upload(Uint8List bytes, String extension);
  Future<void> remove();
}

class SupabaseProfilePhotoRepository implements ProfilePhotoRepository {
  SupabaseProfilePhotoRepository(this._db);
  final SupabaseClient _db;
  static const _bucket = 'avatars';

  String get _uid => _db.auth.currentUser!.id;

  @override
  Future<String?> current() async {
    final row = await _db.from('profiles').select('avatar_url').eq('id', _uid).maybeSingle();
    return row?['avatar_url'] as String?;
  }

  @override
  Future<String> upload(Uint8List bytes, String extension) async {
    final ext = switch (extension.toLowerCase()) { 'png' => 'png', 'webp' => 'webp', _ => 'jpg' };
    final path = '$_uid/${DateTime.now().millisecondsSinceEpoch}.$ext';
    await _db.storage.from(_bucket).uploadBinary(path, bytes,
        fileOptions: FileOptions(contentType: ext == 'jpg' ? 'image/jpeg' : 'image/$ext'));
    final url = _db.storage.from(_bucket).getPublicUrl(path);
    await _db.from('profiles').update({'avatar_url': url}).eq('id', _uid);
    await _deleteOthers(keep: path);
    return url;
  }

  @override
  Future<void> remove() async {
    await _db.from('profiles').update({'avatar_url': null}).eq('id', _uid);
    await _deleteOthers();
  }

  /// Old photos are no longer referenced; a failed clean-up is harmless.
  Future<void> _deleteOthers({String? keep}) async {
    try {
      final files = await _db.storage.from(_bucket).list(path: _uid);
      final stale = [for (final f in files) '$_uid/${f.name}'].where((p) => p != keep).toList();
      if (stale.isNotEmpty) await _db.storage.from(_bucket).remove(stale);
    } catch (_) {}
  }
}

final profilePhotoRepositoryProvider = Provider<ProfilePhotoRepository?>(
  (ref) => AppConfig.hasBackend ? SupabaseProfilePhotoRepository(Supabase.instance.client) : null,
);

/// The signed-in rider's photo URL, or null when they have none (or on demo data).
final profilePhotoProvider = AsyncNotifierProvider<ProfilePhotoController, String?>(ProfilePhotoController.new);

class ProfilePhotoController extends AsyncNotifier<String?> {
  @override
  Future<String?> build() async {
    final user = ref.watch(authControllerProvider);
    final repo = ref.watch(profilePhotoRepositoryProvider);
    if (user == null || repo == null) return null;
    return repo.current();
  }

  bool get available => ref.read(profilePhotoRepositoryProvider) != null;

  Future<void> upload(Uint8List bytes, String extension) async {
    final url = await ref.read(profilePhotoRepositoryProvider)!.upload(bytes, extension);
    state = AsyncData(url);
  }

  Future<void> remove() async {
    await ref.read(profilePhotoRepositoryProvider)!.remove();
    state = const AsyncData(null);
  }
}

/// Lets the rider take, choose or remove a profile photo. Returns a message
/// to show, or null when nothing changed.
Future<String?> changeProfilePhoto(BuildContext context, WidgetRef ref) async {
  final controller = ref.read(profilePhotoProvider.notifier);
  if (!controller.available) return 'Profile photos need an internet connection to the Rent A Ride server.';
  final choice = await showPhotoSourceSheet(
    context,
    hasPhoto: ref.read(profilePhotoProvider).value != null,
    cameraAvailable: !kIsWeb,
  );
  if (choice == null) return null;
  try {
    if (choice == PhotoSourceChoice.remove) {
      await controller.remove();
      return 'Profile photo removed.';
    }
    final file = await ImagePicker().pickImage(
      source: choice == PhotoSourceChoice.camera ? ImageSource.camera : ImageSource.gallery,
      preferredCameraDevice: CameraDevice.front,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    if (bytes.lengthInBytes > 5 * 1024 * 1024) return 'That photo is too large. Choose one under 5 MB.';
    final ext = file.name.contains('.') ? file.name.split('.').last : 'jpg';
    await controller.upload(bytes, ext);
    return 'Profile photo updated.';
  } on PlatformException catch (e) {
    return e.code.contains('camera')
        ? 'Camera not available. Choose from your photos instead.'
        : "Couldn't open your photos. Check the app's photo permission in Settings.";
  } on StorageException catch (e) {
    return e.statusCode == '413'
        ? 'That photo is too large. Choose one under 5 MB.'
        : "Couldn't upload the photo. Check your connection and try again.";
  } catch (_) {
    return "Couldn't update your photo. Check your connection and try again.";
  }
}
