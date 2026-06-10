import 'package:flutter/material.dart';
import '../models/player_model.dart';
import '../theme/colors.dart';
import 'common_widgets.dart';

class RankingList extends StatelessWidget {
  const RankingList({super.key, required this.players});

  final List<PlayerModel> players;

  @override
  Widget build(BuildContext context) {
    final ranking = List<PlayerModel>.from(players)
      ..sort((a, b) => b.bankScore.compareTo(a.bankScore));

    return Column(
      children: ranking.indexed
          .map(
            (entry) => ListTile(
              dense: true,
              title: Text('${entry.$1 + 1}. ${entry.$2.nickname}'),
              trailing: Text(
                '${entry.$2.bankScore} 分',
                style: const TextStyle(
                  color: gold,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ).reveal(entry.$1),
          )
          .toList(),
    );
  }
}
