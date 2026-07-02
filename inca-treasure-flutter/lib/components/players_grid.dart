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
      childAspectRatio: 2.05,
      children: players.indexed.map((entry) {
        final index = entry.$1;
        return _PlayerCard(
          key: playerKeys[entry.$2.id],
          player: entry.$2,
        ).reveal(index);
      }).toList(),
    );
  }
}

/// 单张玩家卡：活跃时呼吸光晕，分数 count-up 滚动，携带宝石以宝石点呈现，
/// 已提交决策显示明确的锁定标记。
class _PlayerCard extends StatefulWidget {
  const _PlayerCard({super.key, required this.player});

  final PlayerModel player;

  @override
  State<_PlayerCard> createState() => _PlayerCardState();
}

class _PlayerCardState extends State<_PlayerCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breath;

  @override
  void initState() {
    super.initState();
    _breath = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    if (widget.player.isActive) _breath.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _PlayerCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.player.isActive && !_breath.isAnimating) {
      _breath.repeat(reverse: true);
    } else if (!widget.player.isActive && _breath.isAnimating) {
      _breath.stop();
      _breath.value = 0;
    }
  }

  @override
  void dispose() {
    _breath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final player = widget.player;
    final active = player.isActive;
    final busted = player.isBusted;
    final accent = busted
        ? ember
        : active
            ? jade
            : Colors.white24;

    return AnimatedBuilder(
      animation: _breath,
      builder: (context, child) {
        final glow = active ? (.12 + _breath.value * .18) : 0.0;
        return AnimatedContainer(
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
            border: Border.all(color: accent, width: active ? 1.4 : 1),
            boxShadow: active
                ? [BoxShadow(color: jade.withValues(alpha: glow), blurRadius: 24)]
                : null,
          ),
          child: child,
        );
      },
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
              if (player.hasSubmitted)
                const Padding(
                  padding: EdgeInsets.only(right: 5),
                  child: Icon(Icons.lock_rounded, size: 13, color: gold),
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
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _CountUp(
                value: player.bankScore,
                style: const TextStyle(
                  fontSize: 25,
                  height: 1,
                  color: bone,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 4),
              const Padding(
                padding: EdgeInsets.only(bottom: 3),
                child: Text('分', style: TextStyle(color: muted, fontSize: 11)),
              ),
            ],
          ),
          const SizedBox(height: 5),
          _GemPips(count: player.temporaryGems),
        ],
      ),
    );
  }
}

/// 分数变化时平滑滚动，而非直接跳数字，呼应宝石飞行落点。
class _CountUp extends StatefulWidget {
  const _CountUp({required this.value, required this.style});

  final int value;
  final TextStyle style;

  @override
  State<_CountUp> createState() => _CountUpState();
}

class _CountUpState extends State<_CountUp> {
  late double _from = widget.value.toDouble();

  @override
  void didUpdateWidget(covariant _CountUp oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _from = oldWidget.value.toDouble();
    }
  }

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: _from, end: widget.value.toDouble()),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => Text('${v.round()}', style: widget.style),
    );
  }
}

/// 携带宝石可视化：每颗一个宝石点，超过 8 颗折叠为 "8+"。
class _GemPips extends StatelessWidget {
  const _GemPips({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) {
      return const Text('营地待命',
          style: TextStyle(color: muted, fontSize: 11));
    }
    final show = count > 8 ? 8 : count;
    return Row(
      children: [
        for (var i = 0; i < show; i += 1)
          Padding(
            padding: const EdgeInsets.only(right: 3),
            child: _pip(i.isEven ? gold : amber),
          ),
        if (count > 8)
          const Padding(
            padding: EdgeInsets.only(left: 1),
            child: Text('+',
                style: TextStyle(
                    color: gold, fontSize: 12, fontWeight: FontWeight.w900)),
          ),
        const SizedBox(width: 4),
        Text('$count',
            style: const TextStyle(
                color: jade, fontSize: 12, fontWeight: FontWeight.w800)),
      ],
    );
  }

  Widget _pip(Color color) => Container(
        width: 9,
        height: 9,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          boxShadow: [
            BoxShadow(color: color.withValues(alpha: .6), blurRadius: 5),
          ],
        ),
      );
}
