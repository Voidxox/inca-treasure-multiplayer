import 'package:flutter/material.dart';
import '../models/card_model.dart';
import '../theme/colors.dart';

class PathStrip extends StatelessWidget {
  const PathStrip({super.key, required this.cards});

  final List<CardModel> cards;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: cards.map((card) {
          return Container(
            width: 39,
            height: 46,
            margin: const EdgeInsets.only(right: 7),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white24),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  card.assetPath ?? 'assets/images/cards/back.png',
                  fit: BoxFit.cover,
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: .22),
                  ),
                ),
                Center(
                  child: Text(
                    card.miniText,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      color: bone,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
