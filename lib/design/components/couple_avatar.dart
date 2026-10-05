import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../icons/profile/profile_doodle_icon.dart';
import '../theme/colors.dart';
import '../theme/spacing.dart';

/// Displays one member's portrait and nickname on a shared journal surface.
class CoupleAvatar extends StatelessWidget {
  const CoupleAvatar({
    required this.avatar,
    required this.nickname,
    required this.label,
    super.key,
  });

  final Uint8List avatar;
  final String nickname;
  final String label;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      SizedBox.square(
        dimension: 80,
        child: CustomPaint(
          foregroundPainter: const ProfileDoodlePainter(showPlus: false),
          child: Padding(
            padding: const EdgeInsets.all(9),
            child: ClipOval(
              child: Image.memory(
                avatar,
                fit: BoxFit.cover,
                excludeFromSemantics: true,
              ),
            ),
          ),
        ),
      ),
      const SizedBox(height: PawmateSpace.small),
      Text(
        nickname,
        textAlign: TextAlign.center,
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
      Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(color: PawmateColors.softBrown),
      ),
    ],
  );
}
