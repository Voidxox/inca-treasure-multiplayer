import 'package:flutter/material.dart';
import '../theme/colors.dart';

class TempleBackdropPainter extends CustomPainter {
  final double t;

  TempleBackdropPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final bg = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [const Color(0xff25170f), ink, const Color(0xff070604)],
      ).createShader(rect);
    canvas.drawRect(rect, bg);

    final glow = Paint()
      ..shader = RadialGradient(
        colors: [
          gold.withValues(alpha: .28 + t * .12),
          Colors.transparent,
        ],
      ).createShader(
        Rect.fromCircle(
          center: Offset(size.width * .5, size.height * .12),
          radius: size.width * .72,
        ),
      );
    canvas.drawRect(rect, glow);

    final line = Paint()
      ..color = Colors.white.withValues(alpha: .045)
      ..strokeWidth = 1;
    for (var x = -size.height; x < size.width; x += 44) {
      canvas.drawLine(
        Offset(x + t * 18, 0),
        Offset(x + size.height + t * 18, size.height),
        line,
      );
    }

    final temple = Paint()..color = amber.withValues(alpha: .16);
    for (var i = 0; i < 5; i++) {
      final w = size.width * (.72 - i * .1);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(size.width / 2, size.height * .76 - i * 28),
            width: w,
            height: 24,
          ),
          const Radius.circular(3),
        ),
        temple,
      );
    }
  }

  @override
  bool shouldRepaint(covariant TempleBackdropPainter oldDelegate) =>
      oldDelegate.t != t;
}
