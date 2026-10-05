import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../icons/profile/profile_doodle_icon.dart';

/// An accessible avatar upload control with a deterministic crayon silhouette.
class CrayonAvatarButton extends StatelessWidget {
  const CrayonAvatarButton({
    required this.label,
    required this.onPressed,
    super.key,
    this.avatar,
  });

  final String label;
  final Uint8List? avatar;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: label,
    child: Semantics(
      label: label,
      button: true,
      enabled: onPressed != null,
      child: Material(
        color: Colors.transparent,
        child: InkResponse(
          onTap: onPressed,
          radius: 56,
          // The crayon artwork stays still; no Material ink overlay or ripple.
          splashFactory: NoSplash.splashFactory,
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          child: SizedBox.square(
            dimension: 112,
            child: CustomPaint(
              foregroundPainter: ProfileDoodlePainter(
                hasAvatar: avatar != null,
              ),
              child: Padding(
                padding: const EdgeInsets.all(13),
                child: avatar == null
                    ? null
                    : ClipOval(child: Image.memory(avatar!, fit: BoxFit.cover)),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
