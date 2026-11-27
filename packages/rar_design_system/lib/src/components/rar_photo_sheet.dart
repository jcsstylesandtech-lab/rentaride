import 'package:flutter/material.dart';

import '../tokens/rar_colors.dart';
import '../tokens/rar_spacing.dart';
import '../tokens/rar_typography.dart';

/// What the person chose in [showPhotoSourceSheet].
enum PhotoSourceChoice { camera, gallery, remove }

/// Bottom sheet: take a photo, choose one, or remove the current one.
/// Returns null when dismissed.
Future<PhotoSourceChoice?> showPhotoSourceSheet(
  BuildContext context, {
  required bool hasPhoto,
  bool cameraAvailable = true,
}) {
  return showModalBottomSheet<PhotoSourceChoice>(
    context: context,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(RarSpacing.lg, 0, RarSpacing.lg, RarSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Profile photo', style: RarTypography.headline),
            const SizedBox(height: RarSpacing.xs),
            Text(
              'Drivers and riders see it during a trip, so use a clear photo of your face.',
              style: RarTypography.bodySmall.copyWith(color: RarColors.textSecondary),
            ),
            const SizedBox(height: RarSpacing.md),
            if (cameraAvailable)
              ListTile(
                key: const ValueKey('photo-camera'),
                leading: const Icon(Icons.photo_camera_rounded, color: RarColors.royal),
                title: const Text('Take a photo'),
                onTap: () => Navigator.pop(context, PhotoSourceChoice.camera),
              ),
            ListTile(
              key: const ValueKey('photo-gallery'),
              leading: const Icon(Icons.photo_library_rounded, color: RarColors.royal),
              title: const Text('Choose from photos'),
              onTap: () => Navigator.pop(context, PhotoSourceChoice.gallery),
            ),
            if (hasPhoto)
              ListTile(
                key: const ValueKey('photo-remove'),
                leading: const Icon(Icons.delete_outline_rounded, color: RarColors.danger),
                title: Text('Remove photo', style: TextStyle(color: RarColors.danger)),
                onTap: () => Navigator.pop(context, PhotoSourceChoice.remove),
              ),
          ],
        ),
      ),
    ),
  );
}
