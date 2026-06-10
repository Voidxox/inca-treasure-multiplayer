import 'card_model.dart';
import 'player_model.dart';

class GameStateModel {
  final int round;
  final String phase; // 'revealing' | 'waitingDecision' | 'roundEnd' | 'gameEnd'
  final int deckCount;
  final List<CardModel> revealedCards;
  final int caveGems;
  final List<int> relics;
  final CardModel? lastCard;
  final List<Map<String, String>> logs;

  const GameStateModel({
    required this.round,
    required this.phase,
    required this.deckCount,
    required this.revealedCards,
    required this.caveGems,
    required this.relics,
    this.lastCard,
    required this.logs,
  });

  factory GameStateModel.fromJson(Map<String, dynamic> json) {
    final listCards = json['revealedCards'] as List? ?? const [];
    final listRelics = json['relics'] as List? ?? const [];
    final listLogs = json['logs'] as List? ?? const [];

    return GameStateModel(
      round: json['round'] as int? ?? 1,
      phase: json['phase']?.toString() ?? 'revealing',
      deckCount: json['deckCount'] as int? ?? 0,
      revealedCards: listCards
          .map((item) => CardModel.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList(),
      caveGems: json['caveGems'] as int? ?? 0,
      relics: listRelics.map((item) => item as int).toList(),
      lastCard: json['lastCard'] != null
          ? CardModel.fromJson(Map<String, dynamic>.from(json['lastCard'] as Map))
          : null,
      logs: listLogs
          .map((item) => {
                'id': (item as Map)['id']?.toString() ?? '',
                'text': item['text']?.toString() ?? '',
              })
          .toList(),
    );
  }

  bool get isGameEnd => phase == 'gameEnd';
  bool get isRoundEnd => phase == 'roundEnd';
  bool get isRevealing => phase == 'revealing';
  bool get isWaitingDecision => phase == 'waitingDecision';

  String get phaseSubtitle {
    if (isGameEnd) return '最终排名已揭晓。';
    if (isRoundEnd) return '本轮结束，等待下一轮。';
    return '同时选择，公开结算。';
  }

  String phaseTitle(PlayerModel? me) {
    if (isGameEnd) return '最终排名';
    if (isRoundEnd) return '本轮结束';
    if (isWaitingDecision && me != null && !me.isActive) {
      return '你已撤退，继续观察';
    }
    if (isWaitingDecision && me != null && me.isActive && !me.hasSubmitted) {
      return '继续，还是撤退？';
    }
    if (isWaitingDecision) return '等待其他玩家';
    return '翻牌中';
  }

  String decisionHint(List<PlayerModel> players, PlayerModel? me) {
    final activeCount = players.where((player) => player.isActive).length;
    if (isRoundEnd) return '有人爆掉或所有人撤退，本轮结束。';
    if (isGameEnd) return '5 轮后按总分排名。';
    if (me != null && !me.isActive) return '你已撤退，本轮仍可能继续。';
    if (me != null && me.hasSubmitted) {
      final waiting = players.where((p) => p.isActive && !p.hasSubmitted).length;
      return '你的选择已提交，等待 $waiting 名玩家。';
    }
    final gems = me?.temporaryGems ?? 0;
    return '你携带 $gems 颗宝石，仍有 $activeCount 人在神庙内。';
  }

  String? get treasureSignature {
    final card = lastCard;
    if (card == null || card.type != 'treasure') return null;
    return '$round-${revealedCards.length}-${card.value}';
  }
}
