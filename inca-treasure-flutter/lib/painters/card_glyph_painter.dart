import 'package:flutter/material.dart';

class CardGlyphPainter extends CustomPainter {
  final String type;

  CardGlyphPainter(this.type);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = Colors.white.withValues(alpha: .09);
    for (var i = 0; i < 5; i++) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            10 + i * 7,
            10 + i * 8,
            size.width - 20 - i * 14,
            size.height - 20 - i * 16,
          ),
          const Radius.circular(10),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CardGlyphPainter oldDelegate) => false;
}
