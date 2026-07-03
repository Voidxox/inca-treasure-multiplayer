import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../models/room_model.dart';

/// 连接状态：用于 UI 区分「在线 / 重连中 / 离线」，而非简单的布尔。
enum ConnStatus { connecting, connected, reconnecting, disconnected }

class SocketService extends ChangeNotifier {
  io.Socket? _socket;
  RoomModel? _room;
  String _message = '';
  MessageKind _messageKind = MessageKind.info;
  ConnStatus _state = ConnStatus.disconnected;
  String? _joinedRoomCode;

  // 重连所需的持久身份：记住自己的 playerId 与所在房间/昵称，
  // 断线重连后自动用 playerId 回到原座位（服务端支持进行中重连）。
  String? _playerId;
  String? _nickname;

  RoomModel? get room => _room;
  String get message => _message;
  MessageKind get messageKind => _messageKind;
  ConnStatus get state => _state;
  bool get connected => _state == ConnStatus.connected;
  String? get joinedRoomCode => _joinedRoomCode;

  void connect(String serverUrl) {
    if (_socket != null) {
      _socket!.dispose();
    }

    _state = ConnStatus.connecting;
    notifyListeners();

    _socket = io.io(
      serverUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          // 开启自动重连：网络抖动 / 切后台恢复后自动重连，并有退避。
          .enableReconnection()
          .setReconnectionAttempts(999)
          .setReconnectionDelay(800)
          .setReconnectionDelayMax(5000)
          .disableAutoConnect()
          .build(),
    );

    _socket!
      ..onConnect((_) {
        _state = ConnStatus.connected;
        // 若此前已在某房间，重连后自动回房（携带 playerId 回到原座位）。
        _autoRejoin();
        notifyListeners();
      })
      ..onReconnectAttempt((_) {
        _state = ConnStatus.reconnecting;
        notifyListeners();
      })
      ..onDisconnect((_) {
        // 有房间信息时视为「重连中」而非彻底离线，UI 提示更准确。
        _state = _joinedRoomCode != null
            ? ConnStatus.reconnecting
            : ConnStatus.disconnected;
        notifyListeners();
      })
      ..on('roomJoined', (payload) {
        final map = payload as Map;
        final code = map['roomCode'] as String;
        _joinedRoomCode = code;
        // 记住服务端分配的 playerId，供后续重连回房使用。
        if (map['playerId'] != null) {
          _playerId = map['playerId'].toString();
        }
        _message = '已加入房间 $code';
        _messageKind = MessageKind.success;
        notifyListeners();
      })
      ..on('stateUpdated', (payload) {
        _room = RoomModel.fromJson(Map<String, dynamic>.from(payload as Map));
        _message = '';
        notifyListeners();
      })
      ..on('errorMessage', (payload) {
        _message = (payload as Map)['message'].toString();
        _messageKind = MessageKind.error;
        notifyListeners();
      });

    _socket!.connect();
  }

  /// 重连成功后，如果之前已加入房间，用持久化的 playerId 自动回到原座位。
  void _autoRejoin() {
    final code = _joinedRoomCode;
    if (code == null || _playerId == null) return;
    _socket?.emit('joinRoom', {
      'roomCode': code,
      'nickname': _nickname ?? '',
      'playerId': _playerId,
    });
  }

  void createRoom(String nickname) {
    _nickname = nickname;
    _socket?.emit('createRoom', {
      'nickname': nickname,
    });
  }

  void joinRoom(String roomCode, String nickname) {
    _nickname = nickname;
    _socket?.emit('joinRoom', {
      'roomCode': roomCode,
      'nickname': nickname,
      if (_playerId != null) 'playerId': _playerId,
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

  /// 主动离开房间：清空本地身份，回到首页。
  void leaveRoom() {
    _room = null;
    _joinedRoomCode = null;
    _playerId = null;
    _message = '';
    notifyListeners();
  }

  @override
  void dispose() {
    _socket?.dispose();
    super.dispose();
  }
}

/// 提示消息语义：区分信息 / 成功 / 错误，供 UI 配色，避免成功提示显示为错误红。
enum MessageKind { info, success, error }

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
