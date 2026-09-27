import 'package:flutter/material.dart';

import 'pawmate_theme.dart';

/// A deterministic house-and-heart doodle used by the pairing header.
class DoodleHouse extends StatelessWidget {
  const DoodleHouse({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 132,
      height: 104,
      child: CustomPaint(painter: _DoodleHousePainter()),
    );
  }
}

class _DoodleHousePainter extends CustomPainter {
  const _DoodleHousePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final outline = Paint()
      ..color = PawmateColors.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()
      ..color = PawmateColors.sun
      ..style = PaintingStyle.fill;

    final house = Path()
      ..moveTo(25, 48)
      ..lineTo(66, 17)
      ..lineTo(108, 48)
      ..lineTo(104, 89)
      ..quadraticBezierTo(66, 94, 28, 89)
      ..close();
    canvas.drawPath(house, fill);
    canvas.drawPath(house, outline);
    canvas.drawLine(const Offset(66, 18), const Offset(66, 8), outline);
    canvas.drawCircle(const Offset(66, 6), 2, outline);

    final door = RRect.fromRectAndRadius(
      const Rect.fromLTWH(56, 61, 20, 29),
      const Radius.circular(4),
    );
    canvas.drawRRect(door, outline);
    canvas.drawCircle(const Offset(71, 76), 1.5, outline);
    canvas.drawRect(const Rect.fromLTWH(38, 52, 15, 14), outline);
    canvas.drawRect(const Rect.fromLTWH(80, 52, 15, 14), outline);
    canvas.drawLine(const Offset(45, 52), const Offset(45, 66), outline);
    canvas.drawLine(const Offset(38, 59), const Offset(53, 59), outline);
    canvas.drawLine(const Offset(87, 52), const Offset(87, 66), outline);
    canvas.drawLine(const Offset(80, 59), const Offset(95, 59), outline);

    final heart = Path()
      ..moveTo(112, 26)
      ..cubicTo(105, 18, 94, 26, 101, 34)
      ..lineTo(112, 44)
      ..lineTo(123, 34)
      ..cubicTo(130, 26, 119, 18, 112, 26)
      ..close();
    canvas.drawPath(heart, Paint()..color = PawmateColors.rose);
    canvas.drawPath(heart, outline);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
