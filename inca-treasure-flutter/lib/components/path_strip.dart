import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/card_model.dart';
import '../theme/colors.dart';

/// 探险步道。
///
/// 把翻出的牌排成一条向神庙深处递进的石板路：最新的牌在右端（前沿）放大高亮，
/// 越往左（历史）越小、越暗，制造 2.5D 的纵深感。翻出新牌后自动滚动到前沿，
/// 通道遗留的宝石以宝石点散落在步道下方。
class PathStrip extends StatefulWidget {
  const PathStrip({super.key, required this.cards, this.caveGems = 0});

  final List<CardModel> cards;
  final int caveGems;

  @override
  State<PathStrip> createState() => _PathStripState();
}

class _PathStripState extends State<PathStrip> {
  final _controller = ScrollController();

  static const _frontHeight = 84.0;
  static const _rearHeight = 52.0;
  static const _spacing = 8.0;

  @override
  void didUpdateWidget(covariant PathStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.cards.length != oldWidget.cards.length) {
      // 翻出新牌，滚到前沿。
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_controller.hasClients) return;
        _controller.animateTo(
          _controller.position.maxScrollExtent,
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeOutCubic,
        );
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cards = widget.cards;
    if (cards.isEmpty) {
      return SizedBox(
        height: _frontHeight + 30,
        child: Center(
          child: Text(
            '步道待启 · 等待第一张牌',
            style: TextStyle(color: muted.withValues(alpha: .7), fontSize: 12),
          ),
        ),
      );
    }

    final last = cards.length - 1;
    return SizedBox(
      height: _frontHeight + 30,
      child: SingleChildScrollView(
        controller: _controller,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var i = 0; i < cards.length; i += 1) ...[
              _StepTile(
                card: cards[i],
                // 距前沿越远越小越暗；前沿（最后一张）满格。
                depth: (last - i),
                isFront: i == last,
                frontHeight: _frontHeight,
                rearHeight: _rearHeight,
              ),
              if (i != last) const SizedBox(width: _spacing),
            ],
            if (widget.caveGems > 0) ...[
              const SizedBox(width: 12),
              _CaveGemStash(count: widget.caveGems, height: _frontHeight),
            ],
          ],
        ),
      ),
    );
  }
}

class _StepTile extends StatelessWidget {
  const _StepTile({
    required this.card,
    required this.depth,
    required this.isFront,
    required this.frontHeight,
    required this.rearHeight,
  });

  final CardModel card;
  final int depth;
  final bool isFront;
  final double frontHeight;
  final double rearHeight;

  @override
  Widget build(BuildContext context) {
    // 纵深衰减：前 5 步内平滑收缩，之后统一为最小尺寸。
    final falloff = (depth / 5).clamp(0.0, 1.0);
    final height = frontHeight - (frontHeight - rearHeight) * falloff;
    final width = height * .78;
    final opacity = 1.0 - .5 * falloff;

    final accent = card.type == 'hazard'
        ? ember
        : card.type == 'relic'
            ? jade
            : gold;

    return Opacity(
      opacity: opacity,
      // 历史牌轻微下沉，前沿抬起，强化「站在前沿」的立体感。
      child: Transform.translate(
        offset: Offset(0, falloff * 8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
          width: width,
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isFront ? accent : Colors.white24,
              width: isFront ? 2 : 1,
            ),
            boxShadow: [
              if (isFront)
                BoxShadow(color: accent.withValues(alpha: .4), blurRadius: 20)
              else
                BoxShadow(
                  color: Colors.black.withValues(alpha: .35),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                card.assetPath ?? 'assets/images/cards/back.png',
                fit: BoxFit.cover,
              ),
              // 底部压暗，让文字浮起。
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: isFront ? .05 : .22),
                      Colors.black.withValues(alpha: .6),
                    ],
                  ),
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    card.miniText,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: isFront ? bone : bone.withValues(alpha: .85),
                      fontSize: isFront ? 18 : 13,
                      shadows: const [
                        Shadow(color: Colors.black, blurRadius: 4),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 通道遗留宝石：散落在步道尽头的小宝石点。
class _CaveGemStash extends StatelessWidget {
  const _CaveGemStash({required this.count, required this.height});

  final int count;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 54,
            height: 42,
            child: CustomPaint(
              painter: _GemStashPainter(math.min(count, 12)),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '通道 $count',
            style: const TextStyle(color: muted, fontSize: 10, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _GemStashPainter extends CustomPainter {
  const _GemStashPainter(this.count);

  final int count;

  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(count * 31 + 7);
    for (var i = 0; i < count; i += 1) {
      final cx = random.nextDouble() * size.width;
      final cy = random.nextDouble() * size.height;
      final r = 3.0 + random.nextDouble() * 2;
      final color = i.isEven ? gold : amber;
      canvas.drawCircle(
        Offset(cx, cy),
        r * 2,
        Paint()
          ..shader = RadialGradient(
            colors: [color.withValues(alpha: .5), Colors.transparent],
          ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r * 2)),
      );
      final path = Path()
        ..moveTo(cx, cy - r)
        ..lineTo(cx + r * .8, cy)
        ..lineTo(cx, cy + r)
        ..lineTo(cx - r * .8, cy)
        ..close();
      canvas.drawPath(path, Paint()..color = color);
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = .8
          ..color = Colors.white.withValues(alpha: .7),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _GemStashPainter oldDelegate) => oldDelegate.count != count;
}
