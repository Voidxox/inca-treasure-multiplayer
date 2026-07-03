import 'package:flutter/material.dart';

import 'theme/colors.dart';
import 'models/room_model.dart';
import 'services/socket_service.dart';
import 'painters/temple_backdrop_painter.dart';
import 'components/common_widgets.dart';
import 'views/home_panel.dart';
import 'views/waiting_room.dart';
import 'views/game_board.dart';

void main() => runApp(const IncaTreasureApp());

class IncaTreasureApp extends StatelessWidget {
  const IncaTreasureApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '印加宝藏',
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: gold,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: ink,
        useMaterial3: true,
      ),
      home: const GamePage(),
    );
  }
}

class GamePage extends StatefulWidget {
  const GamePage({super.key});

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> with SingleTickerProviderStateMixin {
  final SocketService socketService = SocketService();
  late final AnimationController aura;
  final nicknameController = TextEditingController();
  final roomCodeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    aura = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat(reverse: true);

    final uri = Uri.base;
    roomCodeController.text = (uri.queryParameters['room'] ?? '').toUpperCase();
    final server = uri.queryParameters['server'] ?? 'http://127.0.0.1:4174';

    socketService.addListener(_onSocketStateChanged);
    socketService.connect(server);
  }

  void _onSocketStateChanged() {
    final code = socketService.joinedRoomCode;
    if (code != null && code != roomCodeController.text) {
      roomCodeController.text = code;
    }
  }

  @override
  void dispose() {
    socketService.removeListener(_onSocketStateChanged);
    socketService.dispose();
    aura.dispose();
    nicknameController.dispose();
    roomCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SocketServiceProvider(
      service: socketService,
      child: Scaffold(
        body: AnimatedBuilder(
          animation: aura,
          builder: (context, child) => CustomPaint(
            painter: TempleBackdropPainter(aura.value),
            child: child,
          ),
          child: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: ListenableBuilder(
                  listenable: socketService,
                  builder: (context, _) {
                    final currentRoom = socketService.room;
                    final connState = socketService.state;
                    final message = socketService.message;

                    return ListView(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 22),
                      children: [
                        Header(room: currentRoom, state: connState),
                        if (connState == ConnStatus.reconnecting) ...[
                          const SizedBox(height: 10),
                          const ReconnectBanner(),
                        ],
                        const SizedBox(height: 16),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 420),
                          switchInCurve: Curves.easeOutBack,
                          switchOutCurve: Curves.easeInCubic,
                          transitionBuilder: (child, animation) => FadeTransition(
                            opacity: animation,
                            child: SlideTransition(
                              position: Tween(
                                begin: const Offset(0, .06),
                                end: Offset.zero,
                              ).animate(animation),
                              child: child,
                            ),
                          ),
                          child: currentRoom == null
                              ? HomePanel(
                                  key: const ValueKey('home'),
                                  nicknameController: nicknameController,
                                  roomCodeController: roomCodeController,
                                )
                              : currentRoom.isWaiting
                                  ? WaitingRoom(
                                      key: const ValueKey('waiting'),
                                      room: currentRoom,
                                    )
                                  : GameBoard(
                                      key: const ValueKey('game'),
                                      room: currentRoom,
                                    ),
                        ),
                        if (message.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          StatusToast(
                            message: message,
                            kind: socketService.messageKind,
                          ),
                        ],
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class Header extends StatelessWidget {
  const Header({super.key, required this.room, required this.state});

  final RoomModel? room;
  final ConnStatus state;

  @override
  Widget build(BuildContext context) {
    final game = room?.game;
    final title = game == null ? '印加宝藏' : '第 ${game.round}/5 轮';
    final pill = room == null ? '入口' : room!.roomCode;

    // 连接状态三态文案 + 是否点亮。
    final (statusText, statusActive) = switch (state) {
      ConnStatus.connected => ('在线', true),
      ConnStatus.connecting => ('连接中', false),
      ConnStatus.reconnecting => ('重连中', false),
      ConnStatus.disconnected => ('离线', false),
    };

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'ROOM CODE BOARD GAME',
                style: TextStyle(
                  color: gold,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 42,
                  height: .92,
                  fontWeight: FontWeight.w900,
                  color: bone,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                game == null ? '输入房间码，进入同一座神庙。' : game.phaseSubtitle,
                style: const TextStyle(color: muted),
              ),
            ],
          ),
        ),
        GlowPill(
          title: pill,
          subtitle: statusText,
          active: statusActive,
        ),
      ],
    ).reveal(0);
  }
}

/// 断线重连横幅：进行中的对局掉线时给出明确提示，而非让界面静默卡住。
class ReconnectBanner extends StatelessWidget {
  const ReconnectBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: ember.withValues(alpha: .16),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ember.withValues(alpha: .5)),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: ember),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              '连接中断，正在重连…席位已为你保留。',
              style: TextStyle(color: bone, fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
