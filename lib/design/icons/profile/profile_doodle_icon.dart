import 'package:flutter/material.dart';

import '../../theme/colors.dart';
import '../crayon_strokes.dart';

/// Draws a stable wax-textured avatar circle and its upload plus sign.
class ProfileDoodlePainter extends CustomPainter {
  const ProfileDoodlePainter({this.hasAvatar = false, this.showPlus = true});

  final bool hasAvatar;
  final bool showPlus;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 112, size.height / 112);
    final crayon = CrayonStrokes(canvas, seed: 937);
    final circle = Path()
      ..moveTo(56, 7)
      ..cubicTo(83, 5, 106, 30, 104, 57)
      ..cubicTo(107, 84, 80, 107, 54, 104)
      ..cubicTo(27, 106, 5, 81, 8, 53)
      ..cubicTo(6, 27, 29, 6, 56, 7)
      ..close();
    crayon.stroke(circle, PawmateColors.softBrown, width: 3.2);
    if (!showPlus) {
      canvas.restore();
      return;
    }
    final center = hasAvatar ? const Offset(92, 91) : const Offset(56, 56);
    if (hasAvatar) {
      canvas.drawCircle(center, 15, Paint()..color = PawmateColors.paper);
    }
    final extent = hasAvatar ? 8.0 : 15.0;
    crayon.stroke(
      Path()
        ..moveTo(center.dx - extent, center.dy)
        ..lineTo(center.dx + extent, center.dy)
        ..moveTo(center.dx, center.dy - extent)
        ..lineTo(center.dx, center.dy + extent),
      PawmateColors.rose,
      width: 3.4,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(ProfileDoodlePainter oldDelegate) =>
      oldDelegate.hasAvatar != hasAvatar || oldDelegate.showPlus != showPlus;
}
