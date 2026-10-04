import 'package:flutter/material.dart';

import '../../theme/colors.dart';
import '../crayon_strokes.dart';

/// Purpose-based symbols for the four private-home access methods.
enum AccessDoodle { createInvitation, acceptInvitation, restoreHome, addDevice }

/// A native, deterministic crayon illustration, never a substituted bitmap.
class AccessDoodleIcon extends StatelessWidget {
  const AccessDoodleIcon({
    required this.symbol,
    super.key,
    this.size = 80,
    this.color = PawmateColors.rose,
    this.semanticLabel,
  });

  final AccessDoodle symbol;
  final double size;
  final Color color;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) => Semantics(
    label: semanticLabel,
    excludeSemantics: true,
    child: RepaintBoundary(
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(painter: _AccessPainter(symbol, color)),
      ),
    ),
  );
}

class _AccessPainter extends CustomPainter {
  const _AccessPainter(this.symbol, this.color);

  final AccessDoodle symbol;
  final Color color;

  /// Builds a soft, slightly asymmetric journal heart in the icon's 96px space.
  Path _heart(double x, double y, double scale) => Path()
    ..moveTo(x, y + 5 * scale)
    ..cubicTo(
      x - 12 * scale,
      y - 7 * scale,
      x - 21 * scale,
      y + 8 * scale,
      x - 10 * scale,
      y + 17 * scale,
    )
    ..lineTo(x, y + 25 * scale)
    ..lineTo(x + 12 * scale, y + 15 * scale)
    ..cubicTo(
      x + 21 * scale,
      y + 5 * scale,
      x + 10 * scale,
      y - 7 * scale,
      x,
      y + 5 * scale,
    )
    ..close();

  /// Renders each purpose with the same stable pressure/grain vocabulary.
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 96, size.height / 96);
    final crayon = CrayonStrokes(canvas, seed: 410 + symbol.index * 97);
    switch (symbol) {
      case AccessDoodle.createInvitation:
        final envelope = Path()
          ..moveTo(12, 37)
          ..lineTo(68, 35)
          ..lineTo(70, 74)
          ..quadraticBezierTo(39, 77, 14, 73)
          ..close();
        crayon.wash(envelope, color);
        crayon.stroke(envelope, PawmateColors.ink);
        crayon.stroke(
          Path()
            ..moveTo(13, 38)
            ..lineTo(41, 59)
            ..lineTo(68, 36),
          PawmateColors.ink,
        );
        crayon.stroke(
          Path()
            ..moveTo(15, 72)
            ..lineTo(31, 55)
            ..moveTo(51, 54)
            ..lineTo(69, 72),
          PawmateColors.ink,
          width: 1.8,
        );
        final heart = _heart(73, 10, 0.64);
        crayon.wash(heart, color);
        crayon.stroke(heart, PawmateColors.ink, width: 2.3);
        crayon.stroke(
          Path()
            ..moveTo(67, 53)
            ..quadraticBezierTo(86, 51, 85, 36)
            ..moveTo(79, 41)
            ..lineTo(85, 34)
            ..lineTo(90, 41),
          PawmateColors.ink,
        );
      case AccessDoodle.acceptInvitation:
        final open = Path()
          ..moveTo(15, 44)
          ..lineTo(47, 17)
          ..lineTo(80, 42)
          ..lineTo(77, 77)
          ..quadraticBezierTo(47, 80, 18, 76)
          ..close();
        crayon.wash(open, color);
        crayon.stroke(open, PawmateColors.ink);
        final note = Path()
          ..moveTo(28, 29)
          ..lineTo(65, 27)
          ..lineTo(67, 58)
          ..lineTo(28, 59)
          ..close();
        canvas.drawPath(note, Paint()..color = PawmateColors.card);
        crayon.stroke(note, PawmateColors.ink, width: 2.3);
        final heart = _heart(47, 32, 0.55);
        crayon.wash(heart, color);
        crayon.stroke(heart, PawmateColors.ink, width: 2);
        crayon.stroke(
          Path()
            ..moveTo(16, 45)
            ..lineTo(47, 66)
            ..lineTo(79, 43)
            ..moveTo(19, 75)
            ..lineTo(37, 60)
            ..moveTo(58, 59)
            ..lineTo(77, 76),
          PawmateColors.ink,
        );
      case AccessDoodle.restoreHome:
        final box = Path()
          ..moveTo(19, 46)
          ..lineTo(75, 44)
          ..lineTo(73, 78)
          ..quadraticBezierTo(46, 82, 21, 77)
          ..close();
        crayon.wash(box, color);
        crayon.stroke(box, PawmateColors.ink);
        crayon.stroke(
          Path()
            ..moveTo(15, 44)
            ..lineTo(19, 34)
            ..lineTo(77, 32)
            ..lineTo(81, 44)
            ..close(),
          PawmateColors.ink,
        );
        crayon.stroke(
          Path()..addOval(const Rect.fromLTWH(32, 54, 15, 15)),
          PawmateColors.ink,
        );
        crayon.stroke(
          Path()
            ..moveTo(47, 61)
            ..lineTo(64, 61)
            ..lineTo(64, 68)
            ..moveTo(57, 61)
            ..lineTo(57, 67),
          PawmateColors.ink,
        );
        crayon.stroke(
          Path()
            ..moveTo(26, 24)
            ..cubicTo(29, 6, 60, 6, 68, 23)
            ..moveTo(69, 13)
            ..lineTo(69, 25)
            ..lineTo(58, 22),
          PawmateColors.ink,
        );
      case AccessDoodle.addDevice:
        final laptop = Path()
          ..moveTo(13, 24)
          ..lineTo(64, 22)
          ..lineTo(66, 61)
          ..lineTo(14, 63)
          ..close();
        crayon.wash(laptop, color);
        crayon.stroke(laptop, PawmateColors.ink);
        crayon.stroke(
          Path()
            ..moveTo(13, 62)
            ..lineTo(7, 72)
            ..quadraticBezierTo(37, 77, 72, 71)
            ..lineTo(66, 61),
          PawmateColors.ink,
        );
        final phone = Path()
          ..moveTo(59, 38)
          ..quadraticBezierTo(57, 36, 57, 41)
          ..lineTo(58, 79)
          ..quadraticBezierTo(70, 82, 82, 79)
          ..lineTo(82, 38)
          ..close();
        canvas.drawPath(phone, Paint()..color = PawmateColors.card);
        crayon.wash(phone, color);
        crayon.stroke(phone, PawmateColors.ink);
        crayon.stroke(
          Path()
            ..moveTo(65, 43)
            ..lineTo(74, 43)
            ..moveTo(65, 74)
            ..lineTo(74, 74),
          PawmateColors.ink,
          width: 1.8,
        );
        crayon.stroke(
          Path()
            ..moveTo(72, 11)
            ..lineTo(72, 27)
            ..moveTo(64, 19)
            ..lineTo(80, 19),
          PawmateColors.ink,
        );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _AccessPainter oldDelegate) =>
      oldDelegate.symbol != symbol || oldDelegate.color != color;
}
