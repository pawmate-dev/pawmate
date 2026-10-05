import 'package:flutter/material.dart';

import '../../theme/colors.dart';
import '../crayon_strokes.dart';

/// Presentation states only; delivery and read authority remain in features.
enum MessageDelivery { sending, failed, sent, read }

/// Compact, deterministic wax marks for delivery status beside the timestamp.
class MessageStatusIcon extends StatelessWidget {
  const MessageStatusIcon({required this.delivery, super.key});
  final MessageDelivery delivery;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox(
      width: delivery == MessageDelivery.read ? 22 : 16,
      height: 16,
      child: CustomPaint(painter: MessageStatusPainter(delivery)),
    ),
  );
}

/// Uses a fixed per-state seed; no loading spinner or rebuild-time noise.
class MessageStatusPainter extends CustomPainter {
  const MessageStatusPainter(this.delivery);
  final MessageDelivery delivery;

  @override
  void paint(Canvas canvas, Size size) {
    final marks = CrayonStrokes(canvas, seed: 2909 + delivery.index * 31);
    final color = delivery == MessageDelivery.failed
        ? PawmateColors.error
        : PawmateColors.softBrown;
    switch (delivery) {
      case MessageDelivery.failed:
        marks.stroke(
          Path()
            ..moveTo(8, 2)
            ..lineTo(8, 9),
          color,
          width: 2.2,
        );
        marks.stroke(
          Path()..addOval(const Rect.fromLTWH(7, 12, 2, 2)),
          color,
          width: 1.6,
        );
      case MessageDelivery.sent:
      case MessageDelivery.read:
        for (final dx
            in delivery == MessageDelivery.read ? [0.0, 6.0] : [0.0]) {
          marks.stroke(
            Path()
              ..moveTo(2 + dx, 8)
              ..lineTo(6 + dx, 12)
              ..lineTo(14 + dx, 3),
            color,
            width: 1.8,
          );
        }
      case MessageDelivery.sending:
        marks.stroke(
          Path()..addOval(const Rect.fromLTWH(2, 2, 12, 12)),
          color,
          width: 1.4,
        );
        marks.stroke(
          Path()
            ..moveTo(8, 5)
            ..lineTo(8, 8)
            ..lineTo(10, 9),
          color,
          width: 1.4,
        );
    }
  }

  @override
  bool shouldRepaint(MessageStatusPainter oldDelegate) =>
      oldDelegate.delivery != delivery;
}
