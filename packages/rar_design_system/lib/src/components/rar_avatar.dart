import 'package:flutter/material.dart';

import '../tokens/rar_colors.dart';
import '../tokens/rar_typography.dart';

/// A round profile photo, falling back to the person's initial.
///
/// Pass [onEdit] to show a camera badge and make the avatar tappable;
/// [busy] shows a spinner over it while a new photo uploads.
class RarAvatar extends StatelessWidget {
  const RarAvatar({
    super.key,
    required this.name,
    this.imageUrl,
    this.radius = 30,
    this.onEdit,
    this.busy = false,
    this.editLabel = 'Change profile photo',
  });

  final String name;
  final String? imageUrl;
  final double radius;
  final VoidCallback? onEdit;
  final bool busy;
  final String editLabel;

  String get _initial {
    final n = name.trim();
    return n.isEmpty ? '?' : n[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final size = radius * 2;
    final initial = Center(
      child: Text(
        _initial,
        style: (radius >= 26 ? RarTypography.headline : RarTypography.titleSmall)
            .copyWith(color: RarColors.white),
      ),
    );
    final url = imageUrl;

    Widget avatar = Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(shape: BoxShape.circle, color: RarColors.royal),
      child: url == null || url.isEmpty
          ? initial
          : Image.network(
              url,
              fit: BoxFit.cover,
              width: size,
              height: size,
              errorBuilder: (_, _, _) => initial,
              loadingBuilder: (_, child, progress) => progress == null ? child : initial,
            ),
    );

    if (busy) {
      avatar = Stack(children: [
        avatar,
        Container(
          width: size,
          height: size,
          decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0x88061B49)),
          child: const Center(
            child: SizedBox.square(
              dimension: 22,
              child: CircularProgressIndicator(strokeWidth: 2.4, color: RarColors.white),
            ),
          ),
        ),
      ]);
    }

    if (onEdit == null) return Semantics(image: true, excludeSemantics: true, label: '$name profile photo', child: avatar);

    final badge = radius * 0.62;
    return Semantics(
      button: true,
      excludeSemantics: true,
      label: editLabel,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: busy ? null : onEdit,
        child: SizedBox(
          width: size,
          height: size,
          child: Stack(clipBehavior: Clip.none, children: [
            avatar,
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                width: badge,
                height: badge,
                decoration: BoxDecoration(
                  color: RarColors.cyan,
                  shape: BoxShape.circle,
                  border: Border.all(color: RarColors.navy, width: 2),
                ),
                child: Icon(Icons.photo_camera_rounded, size: badge * 0.55, color: RarColors.navy),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
