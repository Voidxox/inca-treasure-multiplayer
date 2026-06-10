import 'package:flutter/material.dart';
import '../services/socket_service.dart';
import '../components/common_widgets.dart';

class HomePanel extends StatelessWidget {
  const HomePanel({
    super.key,
    required this.nicknameController,
    required this.roomCodeController,
  });

  final TextEditingController nicknameController;
  final TextEditingController roomCodeController;

  @override
  Widget build(BuildContext context) {
    final socketService = SocketServiceProvider.of(context);

    return GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SceneTitle(title: '集结探险队', subtitle: '房主创建房间，其他玩家输入房间码加入。'),
          const SizedBox(height: 18),
          FancyField(
            label: '昵称',
            controller: nicknameController,
            hint: '输入你的探险名',
          ),
          const SizedBox(height: 12),
          FancyField(
            label: '房间码',
            controller: roomCodeController,
            hint: '加入时填写',
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ActionButton(
                  label: '创建房间',
                  icon: Icons.temple_buddhist,
                  primary: true,
                  onTap: () => socketService.createRoom(nicknameController.text),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ActionButton(
                  label: '加入房间',
                  icon: Icons.login,
                  onTap: () => socketService.joinRoom(roomCodeController.text, nicknameController.text),
                ),
              ),
            ],
          ),
        ],
      ),
    ).reveal(1);
  }
}
