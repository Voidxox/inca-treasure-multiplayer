import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../models/room_model.dart';

class SocketService extends ChangeNotifier {
  io.Socket? _socket;
  RoomModel? _room;
  String _message = '';
  bool _connected = false;
  String? _joinedRoomCode;

  RoomModel? get room => _room;
  String get message => _message;
  bool get connected => _connected;
  String? get joinedRoomCode => _joinedRoomCode;

  void connect(String serverUrl) {
    if (_socket != null) {
      _socket!.dispose();
    }

    _socket = io.io(
      serverUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .build(),
    );

    _socket!
      ..onConnect((_) {
        _connected = true;
        notifyListeners();
      })
      ..onDisconnect((_) {
        _connected = false;
        notifyListeners();
      })
      ..on('roomJoined', (payload) {
        final code = (payload as Map)['roomCode'] as String;
        _joinedRoomCode = code;
        _message = '已加入房间 $code';
        notifyListeners();
      })
      ..on('stateUpdated', (payload) {
        _room = RoomModel.fromJson(Map<String, dynamic>.from(payload as Map));
        _message = '';
        notifyListeners();
      })
      ..on('errorMessage', (payload) {
        _message = (payload as Map)['message'].toString();
        notifyListeners();
      });

    _socket!.connect();
  }

  void createRoom(String nickname) {
    _socket?.emit('createRoom', {
      'nickname': nickname,
    });
  }

  void joinRoom(String roomCode, String nickname) {
    _socket?.emit('joinRoom', {
      'roomCode': roomCode,
      'nickname': nickname,
    });
  }

  void startGame() {
    _socket?.emit('startGame');
  }

  void submitDecision(String decision) {
    _socket?.emit('submitDecision', {
      'decision': decision,
    });
  }

  void nextRound() {
    _socket?.emit('nextRound');
  }

  @override
  void dispose() {
    _socket?.dispose();
    super.dispose();
  }
}

class SocketServiceProvider extends InheritedWidget {
  final SocketService service;

  const SocketServiceProvider({
    super.key,
    required this.service,
    required super.child,
  });

  static SocketService of(BuildContext context) {
    final provider = context.dependOnInheritedWidgetOfExactType<SocketServiceProvider>();
    assert(provider != null, 'No SocketServiceProvider found in context');
    return provider!.service;
  }

  @override
  bool updateShouldNotify(SocketServiceProvider oldWidget) => service != oldWidget.service;
}
