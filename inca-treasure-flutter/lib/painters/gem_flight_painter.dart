import 'dart:math' as math;
import 'package:flutter/material.dart';

class GemFlight {
  final Offset start;
  final Offset end;
  final Color color;
  final double delay;
  final double size;
  final double arc;

  const GemFlight({
    required this.start,
    required this.end,
    required this.color,
    required this.delay,
    required this.size,
    required this.arc,
  });
}

class GemFlightPainter extends CustomPainter {
  final List<GemFlight> flights;
  final double t;

  const GemFlightPainter({required this.flights, required this.t});

  @override
  void paint(Canvas canvas, Size size) {
    for (final flight in flights) {
      final localT = ((t - flight.delay) / (1 - flight.delay)).clamp(0.0, 1.0);
      if (localT <= 0 || localT >= 1) continue;
      final eased = Curves.easeOutCubic.transform(localT);
      final lift = math.sin(localT * math.pi) * flight.arc;
      final point = Offset.lerp(flight.start, flight.end, eased)! - Offset(0, lift);
      final alpha = localT < .82 ? 1.0 : (1 - localT) / .18;
      final trailStart = Offset.lerp(flight.start, point, .72)!;
      final trailPaint = Paint()
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round
        ..shader = LinearGradient(
          colors: [
            flight.color.withValues(alpha: 0),
            flight.color.withValues(alpha: .55 * alpha),
          ],
        ).createShader(Rect.fromPoints(trailStart, point));
      canvas.drawLine(trailStart, point, trailPaint);
      _drawGem(
        canvas,
        point,
        flight.size * (.85 + .25 * math.sin(localT * math.pi)),
        flight.color,
        alpha,
      );
    }
  }

  void _drawGem(
    Canvas canvas,
    Offset center,
    double radius,
    Color color,
    double alpha,
  ) {
    final glow = Paint()
      ..shader = RadialGradient(
        colors: [
          color.withValues(alpha: .45 * alpha),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius * 2.4));
    canvas.drawCircle(center, radius * 2.2, glow);

    final path = Path()
      ..moveTo(center.dx, center.dy - radius)
      ..lineTo(center.dx + radius * .86, center.dy - radius * .18)
      ..lineTo(center.dx + radius * .52, center.dy + radius)
      ..lineTo(center.dx - radius * .52, center.dy + radius)
      ..lineTo(center.dx - radius * .86, center.dy - radius * .18)
      ..close();
    canvas.drawPath(path, Paint()..color = color.withValues(alpha: alpha));
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = Colors.white.withValues(alpha: .75 * alpha),
    );
    canvas.drawCircle(
      center.translate(-radius * .24, -radius * .22),
      radius * .18,
      Paint()..color = Colors.white.withValues(alpha: .8 * alpha),
    );
  }

  @override
  bool shouldRepaint(covariant GemFlightPainter oldDelegate) =>
      oldDelegate.t != t || oldDelegate.flights != flights;
}
