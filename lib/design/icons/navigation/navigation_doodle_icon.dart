import 'package:flutter/material.dart';

import '../../theme/colors.dart';
import '../crayon_strokes.dart';

/// The three rooms reached from the couple space's icon-only navigation.
enum NavigationDoodle { chat, games, life }

/// Paints a recognizable symbol with stable dry-wax grain and pressure marks.
class NavigationDoodleIcon extends StatelessWidget {
  const NavigationDoodleIcon({
    required this.symbol,
    super.key,
    this.selected = false,
    this.focused = false,
    this.size = 48,
  });

  final NavigationDoodle symbol;
  final bool selected;
  final bool focused;
  final double size;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: RepaintBoundary(
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: NavigationDoodlePainter(
            symbol: symbol,
            selected: selected,
            focused: focused,
          ),
        ),
      ),
    ),
  );
}

/// Shares the existing seeded crayon renderer, never randomizing on rebuild.
class NavigationDoodlePainter extends CustomPainter {
  const NavigationDoodlePainter({
    required this.symbol,
    this.selected = false,
    this.focused = false,
  });

  final NavigationDoodle symbol;
  final bool selected;
  final bool focused;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 64, size.height / 64);
    final crayon = CrayonStrokes(canvas, seed: 1709 + symbol.index * 127);
    final accent = switch (symbol) {
      NavigationDoodle.chat => PawmateColors.rose,
      NavigationDoodle.games => PawmateColors.lavender,
      NavigationDoodle.life => PawmateColors.mint,
    };
    // The underline communicates selection independently of accent color.
    if (selected) {
      crayon.wash(Path()..addOval(const Rect.fromLTWH(9, 10, 47, 40)), accent);
      crayon.stroke(
        Path()
          ..moveTo(21, 57)
          ..quadraticBezierTo(33, 59, 44, 56),
        PawmateColors.ink,
        width: 2.8,
      );
    }
    final ink = selected ? PawmateColors.ink : PawmateColors.softBrown;
    switch (symbol) {
      case NavigationDoodle.chat:
        final bubble = Path()
          ..moveTo(15, 15)
          ..cubicTo(26, 12, 46, 13, 50, 21)
          ..cubicTo(55, 29, 53, 41, 44, 44)
          ..quadraticBezierTo(34, 47, 26, 43)
          ..lineTo(15, 50)
          ..lineTo(18, 40)
          ..cubicTo(7, 35, 7, 20, 15, 15)
          ..close();
        crayon.stroke(bubble, ink, width: 2.8);
        for (final x in [23.0, 32.0, 41.0]) {
          crayon.stroke(
            Path()
              ..addOval(Rect.fromCircle(center: Offset(x, 29), radius: 1.4)),
            ink,
            width: 2,
          );
        }
      case NavigationDoodle.games:
        final controller = Path()
          ..moveTo(21, 20)
          ..quadraticBezierTo(15, 18, 12, 29)
          ..cubicTo(6, 44, 10, 51, 18, 44)
          ..lineTo(25, 38)
          ..quadraticBezierTo(32, 40, 39, 38)
          ..cubicTo(48, 49, 56, 49, 53, 36)
          ..quadraticBezierTo(51, 19, 43, 20)
          ..quadraticBezierTo(32, 23, 21, 20)
          ..close();
        crayon.stroke(controller, ink, width: 2.8);
        crayon.stroke(
          Path()
            ..moveTo(18, 30)
            ..lineTo(28, 31)
            ..moveTo(23, 26)
            ..lineTo(23, 36),
          ink,
          width: 2.5,
        );
        for (final point in [const Offset(42, 28), const Offset(46, 34)]) {
          crayon.stroke(
            Path()..addOval(Rect.fromCircle(center: point, radius: 1.7)),
            ink,
            width: 2,
          );
        }
        // Two linked loops distinguish shared games from a generic gamepad.
        crayon.stroke(
          Path()
            ..addOval(const Rect.fromLTWH(25, 9, 9, 6))
            ..addOval(const Rect.fromLTWH(31, 9, 9, 6)),
          ink,
          width: 2,
        );
      case NavigationDoodle.life:
        // A shared journal with a leaf: everyday life, not a house silhouette.
        crayon.stroke(
          Path()
            ..moveTo(16, 14)
            ..lineTo(45, 13)
            ..quadraticBezierTo(49, 14, 48, 19)
            ..lineTo(49, 46)
            ..quadraticBezierTo(48, 50, 43, 49)
            ..lineTo(16, 50)
            ..quadraticBezierTo(13, 48, 14, 44)
            ..lineTo(14, 19)
            ..quadraticBezierTo(13, 15, 16, 14)
            ..close()
            ..moveTo(21, 15)
            ..lineTo(22, 49),
          ink,
          width: 2.7,
        );
        crayon.stroke(
          Path()
            ..moveTo(31, 39)
            ..quadraticBezierTo(33, 30, 41, 24)
            ..quadraticBezierTo(44, 37, 33, 36)
            ..quadraticBezierTo(26, 33, 27, 28)
            ..quadraticBezierTo(35, 27, 35, 33),
          ink,
          width: 2.2,
        );
    }
    if (focused) {
      crayon.stroke(
        Path()
          ..addRRect(RRect.fromLTRBR(3, 3, 61, 61, const Radius.circular(12))),
        PawmateColors.ink,
        width: 1.8,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(NavigationDoodlePainter oldDelegate) =>
      oldDelegate.symbol != symbol ||
      oldDelegate.selected != selected ||
      oldDelegate.focused != focused;
}
