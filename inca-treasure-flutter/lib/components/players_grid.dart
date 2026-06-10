import 'package:flutter/material.dart';
import '../models/player_model.dart';
import '../theme/colors.dart';
import 'common_widgets.dart';

class PlayersGrid extends StatelessWidget {
  const PlayersGrid({
    super.key,
    required this.players,
    this.playerKeys = const {},
  });

  final List<PlayerModel> players;
  final Map<String, GlobalKey> playerKeys;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      childAspectRatio: 2.18,
      children: players.indexed.map((entry) {
        final player = entry.$2;
        final index = entry.$1;
        final active = player.isActive;
        final busted = player.isBusted;

        return AnimatedContainer(
          key: playerKeys[player.id],
          duration: const Duration(milliseconds: 260),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.white.withValues(alpha: active ? .13 : .07),
                Colors.black.withValues(alpha: .12),
              ],
            ),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: busted
                  ? ember
                  : active
                      ? jade
                      : Colors.white24,
              width: active ? 1.4 : 1,
            ),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: jade.withValues(alpha: .14),
                      blurRadius: 22,
                    ),
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${player.nickname}${player.isHost ? ' · 房主' : ''}',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  Text(
                    player.statusText,
                    style: TextStyle(
                      color: busted
                          ? ember
                          : active
                              ? jade
                              : muted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                '${player.bankScore}',
                style: const TextStyle(
                  fontSize: 25,
                  height: 1,
                  color: bone,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                '携带 ${player.temporaryGems}${player.hasSubmitted ? ' · 已提交' : ''}',
                style: const TextStyle(color: jade, fontSize: 12),
              ),
            ],
          ),
        ).reveal(index);
      }).toList(),
    );
  }
}
