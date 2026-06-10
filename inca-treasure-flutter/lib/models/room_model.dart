import 'game_state_model.dart';
import 'player_model.dart';

class RoomModel {
  final String roomCode;
  final String status; // 'waiting' | 'playing' | 'finished'
  final String hostPlayerId;
  final List<PlayerModel> players;
  final GameStateModel? game;
  final String? meId;

  const RoomModel({
    required this.roomCode,
    required this.status,
    required this.hostPlayerId,
    required this.players,
    this.game,
    this.meId,
  });

  factory RoomModel.fromJson(Map<String, dynamic> json) {
    final listPlayers = json['players'] as List? ?? const [];
    return RoomModel(
      roomCode: json['roomCode']?.toString() ?? '',
      status: json['status']?.toString() ?? 'waiting',
      hostPlayerId: json['hostPlayerId']?.toString() ?? '',
      players: listPlayers
          .map((item) => PlayerModel.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList(),
      game: json['game'] != null
          ? GameStateModel.fromJson(Map<String, dynamic>.from(json['game'] as Map))
          : null,
      meId: json['me']?.toString(),
    );
  }

  PlayerModel? get me {
    if (meId == null) return null;
    for (final player in players) {
      if (player.id == meId) return player;
    }
    return null;
  }

  bool get isWaiting => status == 'waiting';
  bool get isPlaying => status == 'playing';
  bool get isFinished => status == 'finished';
  bool get isHost => me?.isHost ?? false;
}
