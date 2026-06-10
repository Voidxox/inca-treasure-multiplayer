class PlayerModel {
  final String id;
  final String nickname;
  final bool connected;
  final bool isHost;
  final int bankScore;
  final int temporaryGems;
  final String status; // 'waiting' | 'active' | 'left' | 'busted'
  final bool hasSubmitted;

  const PlayerModel({
    required this.id,
    required this.nickname,
    required this.connected,
    required this.isHost,
    required this.bankScore,
    required this.temporaryGems,
    required this.status,
    required this.hasSubmitted,
  });

  factory PlayerModel.fromJson(Map<String, dynamic> json) {
    return PlayerModel(
      id: json['id']?.toString() ?? '',
      nickname: json['nickname']?.toString() ?? '',
      connected: json['connected'] as bool? ?? false,
      isHost: json['isHost'] as bool? ?? false,
      bankScore: json['bankScore'] as int? ?? 0,
      temporaryGems: json['temporaryGems'] as int? ?? 0,
      status: json['status']?.toString() ?? 'waiting',
      hasSubmitted: json['hasSubmitted'] as bool? ?? false,
    );
  }

  bool get isActive => status == 'active';
  bool get isBusted => status == 'busted';
  bool get isLeft => status == 'left';

  String get statusText {
    if (!connected) return '离线';
    switch (status) {
      case 'active':
        return '探险中';
      case 'left':
        return '营地';
      case 'busted':
        return '爆掉';
      default:
        return '等待';
    }
  }
}
