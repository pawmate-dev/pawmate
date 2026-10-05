import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../icons/profile/profile_doodle_icon.dart';
import '../theme/colors.dart';

/// Makes the complete portrait pair one keyboard-accessible, ripple-free action.
class CoupleHeaderButton extends StatelessWidget {
  const CoupleHeaderButton({
    required this.label,
    required this.onPressed,
    required this.child,
    super.key,
  });

  final String label;
  final VoidCallback onPressed;
  final Widget child;

  @override
  Widget build(BuildContext context) => MergeSemantics(
    child: Semantics(
      label: label,
      child: Tooltip(
        message: label,
        excludeFromSemantics: true,
        child: TextButton(
          onPressed: onPressed,
          style:
              TextButton.styleFrom(
                minimumSize: const Size(80, 48),
                padding: const EdgeInsets.symmetric(vertical: 2),
                splashFactory: NoSplash.splashFactory,
                overlayColor: Colors.transparent,
              ).copyWith(
                side: WidgetStateProperty.resolveWith(
                  (states) => states.contains(WidgetState.focused)
                      ? const BorderSide(color: PawmateColors.ink, width: 2)
                      : BorderSide.none,
                ),
              ),
          child: ExcludeSemantics(child: child),
        ),
      ),
    ),
  );
}

/// Overlapping portraits sharing the upload control's deterministic crayon frame.
/// Physical left/right placement stays unchanged across text directions.
class CoupleHeaderAvatars extends StatelessWidget {
  const CoupleHeaderAvatars({
    required this.memberLabel,
    required this.partnerLabel,
    super.key,
    this.memberAvatar,
    this.partnerAvatar,
    this.memberNickname,
    this.partnerNickname,
    this.size = avatarSize,
  }) : assert(size > 0);

  static const avatarSize = 44.0;
  static const overlap = 8.0;

  final Uint8List? memberAvatar;
  final Uint8List? partnerAvatar;
  final String? memberNickname;
  final String? partnerNickname;
  final String memberLabel;
  final String partnerLabel;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size * (2 - overlap / avatarSize),
    height: size,
    child: Stack(
      children: [
        // Paint the right portrait first so the left portrait is always on top.
        Positioned(
          right: 0,
          child: _Portrait(
            avatar: partnerAvatar,
            label: _label(partnerLabel, partnerNickname),
            readingOrder: 1,
            size: size,
          ),
        ),
        Positioned(
          left: 0,
          child: _Portrait(
            avatar: memberAvatar,
            label: _label(memberLabel, memberNickname),
            readingOrder: 0,
            size: size,
          ),
        ),
      ],
    ),
  );

  /// Retains role information when profiles are still loading or unavailable.
  String _label(String role, String? nickname) =>
      nickname == null || nickname.isEmpty ? role : '$role: $nickname';
}

/// A paper-backed portrait that cleanly occludes the partner's lower layer.
class _Portrait extends StatelessWidget {
  const _Portrait({
    required this.avatar,
    required this.label,
    required this.readingOrder,
    required this.size,
  });

  final Uint8List? avatar;
  final String label;
  final double readingOrder;
  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    image: true,
    sortKey: OrdinalSortKey(readingOrder),
    child: Tooltip(
      message: label,
      excludeFromSemantics: true,
      child: SizedBox.square(
        dimension: size,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            color: PawmateColors.paper,
            shape: BoxShape.circle,
          ),
          child: CustomPaint(
            foregroundPainter: const ProfileDoodlePainter(showPlus: false),
            child: Padding(
              padding: EdgeInsets.all(
                size * 5 / CoupleHeaderAvatars.avatarSize,
              ),
              child: ClipOval(
                child: avatar == null
                    ? const CustomPaint(painter: ProfilePlaceholderPainter())
                    : Image.memory(
                        avatar!,
                        fit: BoxFit.cover,
                        excludeFromSemantics: true,
                        errorBuilder: (_, _, _) => const CustomPaint(
                          painter: ProfilePlaceholderPainter(),
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
