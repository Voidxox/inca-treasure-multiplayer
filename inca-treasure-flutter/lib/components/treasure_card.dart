import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/card_model.dart';
import '../theme/colors.dart';
import '../painters/card_glyph_painter.dart';

class TreasureCard extends StatelessWidget {
  const TreasureCard({super.key, this.card});

  final CardModel? card;

  @override
  Widget build(BuildContext context) {
    final current = card ?? const CardModel(type: 'empty');
    final type = current.type;

    List<Color> colors;
    switch (type) {
      case 'hazard':
        colors = [const Color(0xff7b2119), const Color(0xff240c09)];
        break;
      case 'relic':
        colors = [const Color(0xff146052), const Color(0xff0a1b17)];
        break;
      default:
        colors = [const Color(0xff875315), const Color(0xff241206)];
    }

    final asset = current.assetPath;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 720),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..setEntry(3, 2, .001)
          ..rotateY((1 - value) * math.pi / 2),
        child: child,
      ),
      child: Container(
        width: 244,
        height: 336,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: colors,
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: .18)),
          boxShadow: [
            BoxShadow(
              color: (type == 'hazard' ? ember : gold).withValues(alpha: .22),
              blurRadius: 42,
              offset: const Offset(0, 20),
            ),
          ],
        ),
        child: Stack(
          children: [
            if (asset != null)
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(9),
                  child: Image.asset(asset, fit: BoxFit.cover),
                ),
              ),
            if (asset != null)
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(9),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: .38),
                      ],
                    ),
                  ),
                ),
              ),
            Positioned.fill(
              child: CustomPaint(painter: CardGlyphPainter(type)),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  current.kind,
                  style: const TextStyle(
                    color: muted,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
                Expanded(
                  child: Center(
                    child: asset == null
                        ? Text(
                            current.icon,
                            style: TextStyle(
                              fontSize: 68,
                              color: type == 'hazard'
                                  ? ember
                                  : type == 'relic'
                                      ? jade
                                      : gold,
                              fontWeight: FontWeight.w900,
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
                Text(
                  current.title,
                  style: const TextStyle(
                    fontSize: 27,
                    color: bone,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(current.text, style: const TextStyle(color: muted)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
