import 'package:flutter/material.dart';
import 'package:macaron_girlfriend_run/data/enemy_kind.dart';
import 'package:macaron_girlfriend_run/theme/macaron_colors.dart';

/// 可切换角色形态（联机预留男友，一期默认女友）
enum PlayerRole { girlfriend, boyfriend }

/// 关卡轮换的玩家主动技能
enum HeroSkill { dash, shield, petalVolley }

extension HeroSkillPresentation on HeroSkill {
  String get shortLabel => switch (this) {
    HeroSkill.dash => '闪冲',
    HeroSkill.shield => '糖盾',
    HeroSkill.petalVolley => '花弹',
  };
}

/// 世界与关卡常量
class GameConstants {
  GameConstants._();

  static const int worldCount = 9;
  static const int levelsPerWorld = 11;
  static const int totalLevels = worldCount * levelsPerWorld;
  static const int maxDifficulty =
      worldCount + (levelsPerWorld - 1) ~/ 3 + 2 + (worldCount - 1) ~/ 3;

  static const double tileSize = 48;

  /// 重力
  static const double gravity = 1950;
  static const double moveSpeed = 255;
  static const double runSpeed = 380;
  static const double duckMoveSpeedMultiplier = 0.45;

  /// 低难度基础跳跃初速度（向上为负）；正式跳跃按关卡难度计算
  static const double jumpVelocity = -1000;
  static const double superJumpVelocity = -1080;

  static const double coyoteTime = 0.14;
  static const double jumpBuffer = 0.14;
  static const double skillDashDuration = 0.34;
  static const double skillCooldown = 4.6;
  static const double skillDashSpeed = 610;
  static const int maxPlayerShots = 8;

  static const int maxActiveEnemies = 56;
  static const int maxEnemyTraps = 8;
  static const int maxParallaxLayers = 3;

  static const int startingLives = 3;
  static const int maxLives = 5;
  static const int coinScore = 100;
  static const int enemyScore = 200;
  static const int maxEnemyCombo = 5;
  static const int enemyComboBonusStep = 25;
  static const int clearBonus = 1000;
  static const int timeBonusPerSecond = 10;
  static const int levelTimeLimit = 180;

  static const double invincibleDuration = 1.55;
  static const double powerUpDuration = 11;
  static const double enemyTrapDuration = 3.8;
  static const double enemyTrapSlowDuration = 1.05;
  static const double enemyTrapSlowMultiplier = 0.62;
  static const double gardenBuddyDuration = 16.0;
  static const double enemyComboWindow = 3.2;

  /// 相机跑步前瞻像素
  static const double cameraLookAhead = 88;

  /// 柔震屏最大偏移
  static const double cameraShakeMax = 7;

  /// 粒子同时存在上限
  static const int maxFxParticles = 96;

  /// 固体碰撞按列分桶宽度（格）
  static const int solidBucketTiles = 1;

  static double _difficultyProgress(int difficulty) =>
      ((difficulty - 1) / (maxDifficulty - 1)).clamp(0.0, 1.0);

  /// 每关稳定且唯一的装饰种子，不参与地形、碰撞或关卡难度计算。
  static int sceneSeedFor(int worldIndex, int levelIndex) {
    final world = worldIndex.clamp(0, worldCount - 1).toInt();
    final level = levelIndex.clamp(0, levelsPerWorld - 1).toInt();
    return world * levelsPerWorld + level;
  }

  /// 玩家能力随关卡难度平滑收紧，保留可通关的基础跳跃与冲刺距离
  static double playerMoveSpeedFor(int difficulty) =>
      moveSpeed - 18 * _difficultyProgress(difficulty);

  static double playerRunSpeedFor(int difficulty) =>
      runSpeed - 35 * _difficultyProgress(difficulty);

  static double playerJumpVelocityFor(int difficulty) =>
      -(1000 - 40 * _difficultyProgress(difficulty));

  static double playerPoweredJumpVelocityFor(int difficulty) =>
      -(1080 - 60 * _difficultyProgress(difficulty));

  static double playerJumpCutVelocityFor(int difficulty) =>
      playerJumpVelocityFor(difficulty) * 0.55;

  static double playerDashSpeedFor(int difficulty) =>
      610 - 70 * _difficultyProgress(difficulty);

  static double playerDashDurationFor(int difficulty) =>
      skillDashDuration - 0.04 * _difficultyProgress(difficulty);

  static double playerShieldDurationFor(int difficulty) =>
      1.25 - 0.2 * _difficultyProgress(difficulty);

  static int startingLivesFor(
    int difficulty, {
    required int mapWidth,
    int enemyCount = 0,
  }) {
    final lengthReserve = mapWidth >= 180 ? 1 : 0;
    final difficultyReserve = difficulty >= (maxDifficulty * 2 / 3).ceil()
        ? 1
        : 0;
    final combatReserve = enemyCount >= 16
        ? 2
        : enemyCount >= 12
        ? 1
        : 0;
    return (startingLives + lengthReserve + difficultyReserve + combatReserve)
        .clamp(startingLives, maxLives)
        .toInt();
  }

  static double playerSkillCooldownFor(int difficulty) =>
      4.6 + 2.0 * _difficultyProgress(difficulty);

  static HeroSkill heroSkillForLevel(int worldIndex, int levelIndex) =>
      HeroSkill.values[(worldIndex + levelIndex) % HeroSkill.values.length];

  static double playerPowerUpDurationFor(int difficulty) =>
      powerUpDuration - 2.0 * _difficultyProgress(difficulty);

  static double playerGunDurationFor(int difficulty) =>
      13.0 - 2.0 * _difficultyProgress(difficulty);

  static double playerVehicleDurationFor(int difficulty) =>
      7.0 - 1.5 * _difficultyProgress(difficulty);

  static double playerVehicleSpeedMultiplierFor(int difficulty) =>
      1.24 - 0.08 * _difficultyProgress(difficulty);

  static double plantShotCooldownFor(int difficulty) =>
      2.7 + 0.8 * _difficultyProgress(difficulty);

  static double gardenBuddyDurationFor(int difficulty) =>
      gardenBuddyDuration - 3.0 * _difficultyProgress(difficulty);

  static int enemyComboBonusFor(int comboCount) =>
      ((comboCount - 1).clamp(0, maxEnemyCombo - 1) * enemyComboBonusStep)
          .toInt();

  static double enemySkillCooldownFor(int difficulty, EnemyKind kind) {
    final progress = _difficultyProgress(difficulty);
    final start = switch (kind) {
      EnemyKind.walker => 5.3,
      EnemyKind.hopper => 5.8,
      EnemyKind.bruiser => 6.2,
      EnemyKind.trapper => 6.6,
    };
    final end = switch (kind) {
      EnemyKind.walker => 4.0,
      EnemyKind.hopper => 4.2,
      EnemyKind.bruiser => 4.8,
      EnemyKind.trapper => 5.2,
    };
    return start + (end - start) * progress;
  }

  static double enemySkillWarningFor(int difficulty, EnemyKind kind) {
    final progress = _difficultyProgress(difficulty);
    final start = switch (kind) {
      EnemyKind.walker => 0.84,
      EnemyKind.hopper => 0.64,
      EnemyKind.bruiser => 0.78,
      EnemyKind.trapper => 0.9,
    };
    final end = switch (kind) {
      EnemyKind.walker => 0.72,
      EnemyKind.hopper => 0.52,
      EnemyKind.bruiser => 0.64,
      EnemyKind.trapper => 0.76,
    };
    return start + (end - start) * progress;
  }

  static double enemySkillRangeFor(int difficulty, EnemyKind kind) {
    final progress = _difficultyProgress(difficulty);
    final start = switch (kind) {
      EnemyKind.walker => 290.0,
      EnemyKind.hopper => 235.0,
      EnemyKind.bruiser => 270.0,
      EnemyKind.trapper => 245.0,
    };
    final end = switch (kind) {
      EnemyKind.walker => 350.0,
      EnemyKind.hopper => 290.0,
      EnemyKind.bruiser => 330.0,
      EnemyKind.trapper => 305.0,
    };
    return start + (end - start) * progress;
  }

  static double enemyProjectileSpeedFor(int difficulty) =>
      185 + 45 * _difficultyProgress(difficulty);

  static double enemyPounceVelocityFor(int difficulty) =>
      -(600 + 80 * _difficultyProgress(difficulty));

  static double enemyPounceSpeedMultiplierFor(int difficulty) =>
      1.45 + 0.25 * _difficultyProgress(difficulty);

  static double enemyChargeSpeedMultiplierFor(int difficulty) =>
      2.35 + 0.35 * _difficultyProgress(difficulty);

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
