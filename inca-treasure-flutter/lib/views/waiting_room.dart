import 'package:flutter/material.dart';
import '../models/room_model.dart';
import '../services/socket_service.dart';
import '../components/common_widgets.dart';
import '../components/players_grid.dart';

class WaitingRoom extends StatelessWidget {
  const WaitingRoom({super.key, required this.room});

  final RoomModel room;

  @override
  Widget build(BuildContext context) {
    final socketService = SocketServiceProvider.of(context);
    final players = room.players;
    final me = room.me;
    final canStart = me?.isHost == true && players.length >= 2;

    return Column(
      children: [
        GlassPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SceneTitle(title: '神庙门前', subtitle: '分享房间码，等玩家到齐后由房主开始。'),
              const SizedBox(height: 12),
              RoomCodePlate(code: room.roomCode),
              const SizedBox(height: 14),
              ActionButton(
                label: me?.isHost == true ? '开启探险' : '等待房主',
                icon: Icons.play_arrow_rounded,
                primary: true,
                onTap: canStart ? () => socketService.startGame() : null,
              ),
            ],
          ),
        ).reveal(1),
        const SizedBox(height: 12),
        PlayersGrid(players: players).reveal(2),
      ],
    );
  }
}
