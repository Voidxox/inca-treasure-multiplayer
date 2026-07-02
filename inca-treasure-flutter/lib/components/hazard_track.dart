import 'package:flutter/material.dart';
import '../models/card_model.dart';
import '../theme/colors.dart';

/// 危险配对进度条。
///
/// 印加宝藏的核心张力：每种危险第二次出现时，仍在神庙内的玩家全部爆掉。
/// 把「哪种危险已经出现过一次」摊在画面上，让玩家一眼读出风险。
class HazardTrack extends StatelessWidget {
  const HazardTrack({super.key, required this.revealedCards});

  final List<CardModel> revealedCards;

  static const _order = ['snake', 'fire', 'rock', 'spider', 'curse'];
  static const _names = {
    'snake': '毒蛇',
    'fire': '火焰',
    'rock': '落石',
    'spider': '毒蛛',
    'curse': '诅咒',
  };

  // 去饱和矩阵：未出现的危险以灰度呈现。
  static const _greyscale = ColorFilter.matrix(<double>[
    0.2126, 0.7152, 0.0722, 0, 0, //
    0.2126, 0.7152, 0.0722, 0, 0, //
    0.2126, 0.7152, 0.0722, 0, 0, //
    0, 0, 0, 1, 0, //
  ]);

  @override
  Widget build(BuildContext context) {
    final counts = <String, int>{for (final h in _order) h: 0};
    for (final card in revealedCards) {
      if (card.type == 'hazard' && card.hazardType != null) {
        counts[card.hazardType!] = (counts[card.hazardType!] ?? 0) + 1;
      }
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: _order.map((type) {
        final count = counts[type] ?? 0;
        return _HazardSlot(
          type: type,
          name: _names[type]!,
          count: count,
          greyscale: _greyscale,
        );
      }).toList(),
    );
  }
}

class _HazardSlot extends StatelessWidget {
  const _HazardSlot({
    required this.type,
    required this.name,
    required this.count,
    required this.greyscale,
  });

  final String type;
  final String name;
  final int count;
  final ColorFilter greyscale;

  @override
  Widget build(BuildContext context) {
    final armed = count >= 1; // 出现过一次：再来一张就爆。
    final triggered = count >= 2;
    final accent = triggered ? ember : (armed ? ember : Colors.white24);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: accent, width: armed ? 1.8 : 1),
            boxShadow: armed
                ? [BoxShadow(color: ember.withValues(alpha: .34), blurRadius: 16)]
                : null,
          ),
          child: ClipOval(
            child: Stack(
              fit: StackFit.expand,
              children: [
                Opacity(
                  opacity: armed ? 1 : .45,
                  child: armed
                      ? Image.asset('assets/images/cards/$type.png', fit: BoxFit.cover)
                      : ColorFiltered(
                          colorFilter: greyscale,
                          child: Image.asset('assets/images/cards/$type.png', fit: BoxFit.cover),
                        ),
                ),
                if (!armed)
                  DecoratedBox(
                    decoration: BoxDecoration(color: Colors.black.withValues(alpha: .35)),
                  ),
                if (armed)
                  Align(
                    alignment: Alignment.topRight,
                    child: Container(
                      margin: const EdgeInsets.all(2),
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: ember,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        triggered ? '!!' : '1',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          height: 1,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          name,
          style: TextStyle(
            color: armed ? bone : muted,
            fontSize: 10,
            fontWeight: armed ? FontWeight.w900 : FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
