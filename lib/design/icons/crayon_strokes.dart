import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Draws dry-wax strokes with seeded pressure variation, grain and small gaps.
/// Geometry is sampled from native paths; the seed never depends on build time.
class CrayonStrokes {
  CrayonStrokes(this.canvas, {required int seed}) : _random = math.Random(seed);

  final Canvas canvas;
  final math.Random _random;

  /// Layers translucent, slightly offset marks along a recognizable silhouette.
  void stroke(Path path, Color color, {double width = 2.8}) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    for (final metric in path.computeMetrics()) {
      for (var distance = 0.0; distance < metric.length; distance += 1.8) {
        final start = metric.getTangentForOffset(distance)!;
        final end = metric.getTangentForOffset(
          math.min(distance + 1.9, metric.length),
        )!;
        final normal = Offset(-start.vector.dy, start.vector.dx);
        final pressure = 0.72 + _random.nextDouble() * 0.45;
        final drift = normal * ((_random.nextDouble() - 0.5) * 0.75);
        // Short dry patches expose the actual paper beneath, not painted white.
        if (_random.nextDouble() > 0.045) {
          paint
            ..color = color.withAlpha(155 + _random.nextInt(85))
            ..strokeWidth = width * pressure;
          canvas.drawLine(start.position + drift, end.position + drift, paint);
        }
        // An uneven second pressure line supplies rough edges and pigment grain.
        paint
          ..color = color.withAlpha(45 + _random.nextInt(80))
          ..strokeWidth = 0.45 + _random.nextDouble() * 0.7;
        final edge = normal * (width * (_random.nextDouble() - 0.5));
        canvas.drawLine(start.position + edge, end.position + edge, paint);
      }
    }
  }

  /// Adds a restrained crayon wash with hatch marks and scattered pigment.
  void wash(Path shape, Color color) {
    final bounds = shape.getBounds();
    canvas.drawPath(shape, Paint()..color = color.withAlpha(38));
    canvas.save();
    canvas.clipPath(shape);
    final paint = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3.2;
    for (var y = bounds.top; y < bounds.bottom + 12; y += 4.5) {
      paint.color = color.withAlpha(45 + _random.nextInt(45));
      canvas.drawLine(
        Offset(bounds.left, y),
        Offset(bounds.right, y - 9 + _random.nextDouble()),
        paint,
      );
    }
    for (var i = 0; i < 100; i++) {
      paint.color = color.withAlpha(70 + _random.nextInt(70));
      canvas.drawCircle(
        Offset(
          bounds.left + _random.nextDouble() * bounds.width,
          bounds.top + _random.nextDouble() * bounds.height,
        ),
        0.3 + _random.nextDouble() * 0.6,
        paint,
      );
    }
    canvas.restore();
  }
}
