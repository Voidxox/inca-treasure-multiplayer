import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../models/room_model.dart';
import '../models/player_model.dart';
import '../models/game_state_model.dart';
import '../theme/colors.dart';
import '../services/socket_service.dart';
import '../painters/gem_flight_painter.dart';

import '../components/common_widgets.dart';
import '../components/players_grid.dart';
import '../components/treasure_card.dart';
import '../components/path_strip.dart';
import '../components/log_list.dart';
import '../components/ranking_list.dart';

class GameBoard extends StatefulWidget {
  const GameBoard({super.key, required this.room});

  final RoomModel room;

  @override
  State<GameBoard> createState() => _GameBoardState();
}

class _GameBoardState extends State<GameBoard> with SingleTickerProviderStateMixin {
  final boardKey = GlobalKey();
  final cardKey = GlobalKey();
  final playerKeys = <String, GlobalKey>{};
  late final AnimationController gemFlight;
  List<GemFlight> flights = const [];
  String? lastTreasureSignature;
  int flightSeed = 0;

  @override
  void initState() {
    super.initState();
    gemFlight = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1180),
    );
    lastTreasureSignature = widget.room.game?.treasureSignature;
    _syncPlayerKeys(widget.room.players);
  }

  @override
  void didUpdateWidget(covariant GameBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final players = widget.room.players;
    _syncPlayerKeys(players);
    final game = widget.room.game;
    final signature = game?.treasureSignature;
    if (signature != null && signature != lastTreasureSignature) {
      lastTreasureSignature = signature;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _launchGemFlights(game!, players),
      );
    } else if (signature == null) {
      lastTreasureSignature = null;
    }
  }

  @override
  void dispose() {
    gemFlight.dispose();
    super.dispose();
  }

  void _syncPlayerKeys(List<PlayerModel> players) {
    final ids = players.map((p) => p.id).toSet();
    playerKeys.removeWhere((id, _) => !ids.contains(id));
    for (final id in ids) {
      playerKeys.putIfAbsent(id, GlobalKey.new);
    }
  }

  void _launchGemFlights(GameStateModel game, List<PlayerModel> players) {
    if (!mounted || MediaQuery.maybeOf(context)?.disableAnimations == true) {
      return;
    }
    final boardBox = boardKey.currentContext?.findRenderObject() as RenderBox?;
    final cardBox = cardKey.currentContext?.findRenderObject() as RenderBox?;
    if (boardBox == null || cardBox == null || !boardBox.hasSize || !cardBox.hasSize) {
      return;
    }

    final cardCenter = boardBox.globalToLocal(
      cardBox.localToGlobal(cardBox.size.center(Offset.zero)),
    );
    final targets = <Offset>[];
    for (final player in players) {
      if (!player.isActive) continue;
      final box = playerKeys[player.id]?.currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) continue;
      targets.add(
        boardBox.globalToLocal(
          box.localToGlobal(Offset(box.size.width - 34, box.size.height - 24)),
        ),
      );
    }
    if (targets.isEmpty) return;

    final value = game.lastCard?.value ?? 0;
    final countPerPlayer = value >= 9
        ? 4
        : value >= 4
            ? 3
            : 2;
    final random = math.Random(value + targets.length + flightSeed++);
    final nextFlights = <GemFlight>[];
    for (var targetIndex = 0; targetIndex < targets.length; targetIndex += 1) {
      for (var gemIndex = 0; gemIndex < countPerPlayer; gemIndex += 1) {
        final spread = Offset(
          random.nextDouble() * 24 - 12,
          random.nextDouble() * 18 - 9,
        );
        nextFlights.add(
          GemFlight(
            start: cardCenter +
                Offset(
                  random.nextDouble() * 54 - 27,
                  random.nextDouble() * 72 - 36,
                ),
            end: targets[targetIndex] + spread,
            color: game.lastCard!.getGemColor(gemIndex),
            delay: (targetIndex * .08 + gemIndex * .035).clamp(0, .38).toDouble(),
            size: 12 + random.nextDouble() * 8,
            arc: 56 + random.nextDouble() * 42,
          ),
        );
      }
    }
    setState(() => flights = nextFlights);
    gemFlight.forward(from: 0).whenComplete(() {
      if (mounted) setState(() => flights = const []);
    });
  }

  @override
  Widget build(BuildContext context) {
    final socketService = SocketServiceProvider.of(context);
    final players = widget.room.players;
    final game = widget.room.game;

    if (game == null) return const SizedBox.shrink();

    final me = widget.room.me;
    final canDecide = game.isWaitingDecision && me != null && me.isActive && !me.hasSubmitted;
    final isHost = widget.room.isHost;

    return Stack(
      key: boardKey,
      clipBehavior: Clip.none,
      children: [
        Column(
          children: [
            PlayersGrid(players: players, playerKeys: playerKeys).reveal(1),
            const SizedBox(height: 12),
            GlassPanel(
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: SceneTitle(
                          title: game.phaseTitle(me),
                          subtitle: game.decisionHint(players, me),
                        ),
                      ),
                      GlowPill(
                        title: '${game.caveGems}',
                        subtitle: '通道遗留',
                        active: game.caveGems > 0,
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 520),
                    transitionBuilder: (child, animation) => RotationTransition(
                      turns: Tween(begin: -.025, end: 0.0).animate(animation),
                      child: ScaleTransition(
                        scale: CurvedAnimation(
                          parent: animation,
                          curve: Curves.easeOutBack,
                        ),
                        child: FadeTransition(opacity: animation, child: child),
                      ),
                    ),
                    child: TreasureCard(
                      key: cardKey,
                      card: game.lastCard,
                    ),
                  ),
                  const SizedBox(height: 14),
                  PathStrip(cards: game.revealedCards),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ActionButton(
                          label: game.isWaitingDecision && me != null && !me.isActive
                              ? '已撤退'
                              : game.isWaitingDecision
                                  ? '撤退'
                                  : '等待',
                          icon: Icons.output_rounded,
                          onTap: canDecide ? () => socketService.submitDecision('leave') : null,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ActionButton(
                          label: game.isWaitingDecision && me != null && !me.isActive
                              ? '观察中'
                              : game.isWaitingDecision
                                  ? '继续深入'
                                  : '下一轮',
                          icon: Icons.explore_rounded,
                          primary: true,
                          onTap: game.isWaitingDecision
                              ? (canDecide ? () => socketService.submitDecision('continue') : null)
                              : (isHost && game.isRoundEnd ? () => socketService.nextRound() : null),
                        ),
                      ),
                    ],
                  ),
                  if (game.isGameEnd) RankingList(players: players),
                  const SizedBox(height: 12),
                  LogList(logs: game.logs),
                ],
              ),
            ).reveal(2),
          ],
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: GemFlightLayer(controller: gemFlight, flights: flights),
          ),
        ),
      ],
    );
  }
}

class GemFlightLayer extends StatelessWidget {
  const GemFlightLayer({
    super.key,
    required this.controller,
    required this.flights,
  });

  final Animation<double> controller;
  final List<GemFlight> flights;

  @override
  Widget build(BuildContext context) {
    if (flights.isEmpty) return const SizedBox.shrink();
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) => CustomPaint(
        painter: GemFlightPainter(flights: flights, t: controller.value),
      ),
    );
  }
}
