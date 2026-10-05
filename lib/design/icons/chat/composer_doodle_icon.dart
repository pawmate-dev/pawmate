import 'package:flutter/material.dart';

import '../../theme/colors.dart';
import '../crayon_strokes.dart';

/// Extensible composer symbols, independent of upload or message state.
enum ComposerDoodle { add, stickers, send, file, photo, save, close }

/// Small purpose-seeded crayon silhouettes for the chat action strip.
class ComposerDoodleIcon extends StatelessWidget {
  const ComposerDoodleIcon({
    required this.symbol,
    super.key,
    this.enabled = true,
  });
  final ComposerDoodle symbol;
  final bool enabled;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox.square(
      dimension: 28,
      child: CustomPaint(
        painter: ComposerDoodlePainter(symbol, enabled: enabled),
      ),
    ),
  );
}

/// Never varies texture or geometry while typing, pressing or rebuilding.
class ComposerDoodlePainter extends CustomPainter {
  const ComposerDoodlePainter(this.symbol, {this.enabled = true});
  final ComposerDoodle symbol;
  final bool enabled;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 32, size.height / 32);
    final strokes = CrayonStrokes(canvas, seed: 4001 + symbol.index * 97);
    final color = enabled
        ? PawmateColors.ink
        : PawmateColors.softBrown.withAlpha(120);
    final path = Path();
    switch (symbol) {
      case ComposerDoodle.close:
        path
          ..moveTo(7, 7)
          ..lineTo(25, 25)
          ..moveTo(25, 7)
          ..lineTo(7, 25);
      case ComposerDoodle.save:
        path
          ..moveTo(16, 3)
          ..lineTo(16, 22)
          ..moveTo(9, 15)
          ..lineTo(16, 22)
          ..lineTo(23, 15)
          ..moveTo(5, 22)
          ..lineTo(5, 28)
          ..lineTo(27, 28)
          ..lineTo(27, 22);
      case ComposerDoodle.add:
        path
          ..moveTo(5, 16)
          ..lineTo(27, 16)
          ..moveTo(16, 5)
          ..lineTo(16, 27);
      case ComposerDoodle.stickers:
        path
          ..moveTo(8, 4)
          ..quadraticBezierTo(3, 4, 3, 10)
          ..lineTo(4, 24)
          ..quadraticBezierTo(4, 28, 10, 28)
          ..lineTo(22, 28)
          ..lineTo(29, 20)
          ..lineTo(28, 9)
          ..quadraticBezierTo(28, 3, 22, 4)
          ..close()
          ..moveTo(22, 28)
          ..lineTo(22, 21)
          ..lineTo(29, 20)
          ..moveTo(9, 12)
          ..lineTo(10, 12)
          ..moveTo(21, 12)
          ..lineTo(22, 12)
          ..moveTo(10, 18)
          ..quadraticBezierTo(16, 24, 21, 18);
      case ComposerDoodle.send:
        path
          ..moveTo(4, 5)
          ..lineTo(29, 16)
          ..lineTo(4, 27)
          ..lineTo(9, 16)
          ..close()
          ..moveTo(9, 16)
          ..lineTo(29, 16);
      case ComposerDoodle.file:
        path
          ..moveTo(8, 3)
          ..lineTo(21, 3)
          ..lineTo(27, 10)
          ..lineTo(27, 29)
          ..lineTo(7, 28)
          ..close()
          ..moveTo(21, 3)
          ..lineTo(20, 11)
          ..lineTo(27, 10)
          ..moveTo(12, 17)
          ..lineTo(22, 17)
          ..moveTo(12, 22)
          ..lineTo(21, 23);
      case ComposerDoodle.photo:
        path
          ..moveTo(4, 6)
          ..lineTo(28, 5)
          ..lineTo(29, 27)
          ..lineTo(3, 26)
          ..close()
          ..moveTo(4, 23)
          ..lineTo(12, 15)
          ..lineTo(18, 21)
          ..lineTo(23, 16)
          ..lineTo(29, 24)
          ..addOval(const Rect.fromLTWH(18, 9, 5, 5));
    }
    strokes.stroke(path, color, width: 2.0);
    canvas.restore();
  }

  @override
  bool shouldRepaint(ComposerDoodlePainter oldDelegate) =>
      oldDelegate.symbol != symbol || oldDelegate.enabled != enabled;
}
