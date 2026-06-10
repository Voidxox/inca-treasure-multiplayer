import 'package:flutter/material.dart';
import '../theme/colors.dart';

class CardModel {
  final String type; // 'treasure' | 'hazard' | 'relic' | 'empty'
  final int? value;
  final String? hazardType; // 'snake' | 'fire' | 'rock' | 'spider' | 'curse'

  const CardModel({
    required this.type,
    this.value,
    this.hazardType,
  });

  factory CardModel.fromJson(Map<String, dynamic> json) {
    return CardModel(
      type: json['type']?.toString() ?? 'empty',
      value: json['value'] as int?,
      hazardType: json['hazardType']?.toString(),
    );
  }

  String get kind {
    switch (type) {
      case 'treasure':
        return '宝石';
      case 'hazard':
        return '危险';
      case 'relic':
        return '遗物';
      default:
        return '入口';
    }
  }

  String get icon {
    switch (type) {
      case 'treasure':
        return '◆';
      case 'hazard':
        return '!';
      case 'relic':
        return '⬟';
      default:
        return '◆';
    }
  }

  String get title {
    switch (type) {
      case 'treasure':
        return '$value 颗';
      case 'hazard':
        return hazardName;
      case 'relic':
        return '$value 分';
      default:
        return '等待翻牌';
    }
  }

  String get text {
    switch (type) {
      case 'treasure':
        return '仍在神庙内的玩家平分，余数留在通道。';
      case 'hazard':
        return '同类危险第二次出现时，仍在神庙内的玩家爆掉。';
      case 'relic':
        return '只有一人撤退时可以带走遗物。';
      default:
        return '所有选择提交后会继续深入。';
    }
  }

  String get miniText {
    switch (type) {
      case 'treasure':
        return '$value';
      case 'hazard':
        return hazardName.isNotEmpty ? hazardName.substring(0, 1) : '?';
      case 'relic':
        return '⬟';
      default:
        return '?';
    }
  }

  String get hazardName {
    switch (hazardType) {
      case 'snake':
        return '毒蛇';
      case 'fire':
        return '火焰';
      case 'rock':
        return '落石';
      case 'spider':
        return '毒蛛';
      case 'curse':
        return '诅咒';
      default:
        return '危险';
    }
  }

  String? get assetPath {
    String? name;
    switch (type) {
      case 'treasure':
        name = _treasureAssetName(value ?? 0);
        break;
      case 'hazard':
        name = hazardType;
        break;
      case 'relic':
        name = 'relic';
        break;
      case 'empty':
        name = 'back';
        break;
    }
    return name == null ? null : 'assets/images/cards/$name.png';
  }

  String _treasureAssetName(int val) {
    if (val <= 3) return 'topaz';
    if (val <= 5) return 'emerald';
    if (val <= 9) return 'sapphire';
    if (val <= 13) return 'amethyst';
    return 'ruby';
  }

  Color getGemColor(int offset) {
    final name = _treasureAssetName(value ?? 0);
    List<Color> palette;
    switch (name) {
      case 'topaz':
        palette = [const Color(0xffffc857), const Color(0xffffe6a3)];
        break;
      case 'emerald':
        palette = [jade, const Color(0xffb9ffd7)];
        break;
      case 'sapphire':
        palette = [const Color(0xff58a6ff), const Color(0xffb9d8ff)];
        break;
      case 'amethyst':
        palette = [const Color(0xffb878ff), const Color(0xffe2c5ff)];
        break;
      default: // ruby
        palette = [const Color(0xffff4d6d), const Color(0xffffb3c1)];
    }
    return palette[offset % palette.length];
  }
}
