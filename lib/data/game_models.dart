import 'package:flutter/material.dart';
import 'package:macaron_girlfriend_run/theme/macaron_colors.dart';

/// 可切换角色形态（联机预留男友，一期默认女友）
enum PlayerRole {
  girlfriend,
  boyfriend,
}

/// 世界与关卡常量
class GameConstants {
  GameConstants._();

  static const int worldCount = 9;
  static const int levelsPerWorld = 11;
  static const int totalLevels = worldCount * levelsPerWorld;

  static const double tileSize = 48;
  static const double gravity = 2400;
  static const double moveSpeed = 230;
  static const double runSpeed = 340;
  static const double jumpVelocity = -880;
  static const double superJumpVelocity = -1040;
  static const double coyoteTime = 0.12;
  static const double jumpBuffer = 0.12;

  static const int maxActiveEnemies = 24;
  static const int maxParallaxLayers = 3;

  static const int startingLives = 3;
  static const int maxLives = 5;
  static const int coinScore = 100;
  static const int enemyScore = 200;
  static const int clearBonus = 1000;
  static const int timeBonusPerSecond = 10;
  static const int levelTimeLimit = 180;

  static const double invincibleDuration = 1.55;
  static const double powerUpDuration = 11;

  /// 按关卡难度与地图长度计算限时秒数
  static double timeLimitFor(int difficulty, {required int mapWidth}) {
    final stretchBonus = mapWidth * 0.72;
    return (128 + stretchBonus - difficulty * 6).clamp(115, 280).toDouble();
  }

  /// 按关卡难度计算小怪移动速度
  static double enemySpeedFor(int difficulty) {
    return 80 + difficulty * 11;
  }

  /// 难度档位中文标签
  static String difficultyLabel(int difficulty) {
    if (difficulty <= 2) {
      return '简单';
    }
    if (difficulty <= 5) {
      return '中等';
    }
    if (difficulty <= 9) {
      return '挑战';
    }
    if (difficulty <= 13) {
      return '高手';
    }
    return '大师';
  }
}

/// 单关瓦片数据
class LevelData {
  const LevelData({
    required this.worldIndex,
    required this.levelIndex,
    required this.title,
    required this.rows,
    required this.difficulty,
  });

  final int worldIndex;
  final int levelIndex;
  final String title;
  final List<String> rows;
  final int difficulty;

  int get width => rows.isEmpty ? 0 : rows.first.length;
  int get height => rows.length;

  String tileAt(int x, int y) {
    if (y < 0 || y >= rows.length) {
      return ' ';
    }
    final row = rows[y];
    if (x < 0 || x >= row.length) {
      return ' ';
    }
    return row[x];
  }
}

/// 九大世界主题
class WorldCatalog {
  WorldCatalog._();

  static const List<WorldPalette> palettes = [
    WorldPalette(
      name: '奶油草地',
      skyTop: Color(0xFFFFE8F0),
      skyBottom: Color(0xFFB8E0FF),
      ground: Color(0xFF9FE8C0),
      groundDark: Color(0xFF6FCB9A),
      accent: MacaronColors.blush,
      parallaxFar: Color(0x55FFB4C8),
      parallaxMid: Color(0x66B8F0D8),
    ),
    WorldPalette(
      name: '草莓甜点',
      skyTop: Color(0xFFFFD6E5),
      skyBottom: Color(0xFFFFF0F5),
      ground: Color(0xFFFF9EBB),
      groundDark: Color(0xFFE8789C),
      accent: MacaronColors.lemon,
      parallaxFar: Color(0x55FFE6A7),
      parallaxMid: Color(0x66FFB4C8),
    ),
    WorldPalette(
      name: '薄荷汽水',
      skyTop: Color(0xFFD8FFF2),
      skyBottom: Color(0xFFB8E0FF),
      ground: Color(0xFF7ED9C2),
      groundDark: Color(0xFF4FB89E),
      accent: MacaronColors.sky,
      parallaxFar: Color(0x55B8E0FF),
      parallaxMid: Color(0x66B8F0D8),
    ),
    WorldPalette(
      name: '香芋星空',
      skyTop: Color(0xFF2A1F4D),
      skyBottom: Color(0xFF6B5B95),
      ground: Color(0xFFB39DDB),
      groundDark: Color(0xFF8571B3),
      accent: MacaronColors.lilac,
      parallaxFar: Color(0x44D4C4F5),
      parallaxMid: Color(0x55FFB4C8),
    ),
    WorldPalette(
      name: '柠檬沙滩',
      skyTop: Color(0xFFFFF3C4),
      skyBottom: Color(0xFFB8E0FF),
      ground: Color(0xFFFFE082),
      groundDark: Color(0xFFE6C35C),
      accent: MacaronColors.mint,
      parallaxFar: Color(0x55FFE6A7),
      parallaxMid: Color(0x66B8E0FF),
    ),
    WorldPalette(
      name: '玫瑰城堡',
      skyTop: Color(0xFFFFE0EC),
      skyBottom: Color(0xFFD4C4F5),
      ground: Color(0xFFE89AB5),
      groundDark: Color(0xFFC46F8E),
      accent: MacaronColors.lilac,
      parallaxFar: Color(0x55D4C4F5),
      parallaxMid: Color(0x66FFB4C8),
    ),
    WorldPalette(
      name: '蓝莓峡谷',
      skyTop: Color(0xFFB3D4FF),
      skyBottom: Color(0xFFE8F4FF),
      ground: Color(0xFF7E9FE0),
      groundDark: Color(0xFF5A7BC4),
      accent: MacaronColors.blush,
      parallaxFar: Color(0x557E9FE0),
      parallaxMid: Color(0x66B8E0FF),
    ),
    WorldPalette(
      name: '焦糖矿山',
      skyTop: Color(0xFFFFE8D6),
      skyBottom: Color(0xFFFFF6F0),
      ground: Color(0xFFD4A574),
      groundDark: Color(0xFFB8844F),
      accent: MacaronColors.lemon,
      parallaxFar: Color(0x55D4A574),
      parallaxMid: Color(0x66FFE6A7),
    ),
    WorldPalette(
      name: '蜜月彩虹',
      skyTop: Color(0xFFFFD6F0),
      skyBottom: Color(0xFFD6F5FF),
      ground: Color(0xFFFFB4C8),
      groundDark: Color(0xFFE891B0),
      accent: MacaronColors.mint,
      parallaxFar: Color(0x55D4C4F5),
      parallaxMid: Color(0x66B8F0D8),
    ),
  ];

  static WorldPalette paletteOf(int worldIndex) =>
      palettes[worldIndex.clamp(0, palettes.length - 1)];
}
