import 'dart:math' as math;

import 'package:macaron_girlfriend_run/data/enemy_kind.dart';
import 'package:macaron_girlfriend_run/data/game_models.dart';

/// 敌人巡逻边界的纯逻辑计算：不依赖 Flame，便于单元测试与复用。
///
/// 规则：
/// - 基础巡逻在出生点左右各延伸最多两格，前提是落点安全（有地面、头顶净空、避开检查点）。
/// - 若左右存在相邻敌人，则收紧本侧边界，保证两段巡逻之间留有「反应间距」，
///   让玩家在敌人之间仍有落脚与观察空间。
class EnemyPatrol {
  EnemyPatrol._();

  static const double bruiserHalfWidth = 26.0;
  static const double defaultHalfWidth = 21.0;

  /// 敌人的碰撞半宽（像素）
  static const double shellHalfWidth = 24.0;
  static const double rollerHalfWidth = 23.0;

  static double halfWidthOf(EnemyKind kind) => switch (kind) {
    EnemyKind.bruiser => bruiserHalfWidth,
    EnemyKind.shell => shellHalfWidth,
    EnemyKind.roller => rollerHalfWidth,
    _ => defaultHalfWidth,
  };

  /// 地面标记 → 敌人种类
  static EnemyKind? kindOfMarker(String marker) => switch (marker) {
    'E' => EnemyKind.walker,
    'G' => EnemyKind.hopper,
    'R' => EnemyKind.bruiser,
    'T' => EnemyKind.trapper,
    'A' => EnemyKind.swooper,
    'L' => EnemyKind.shell,
    'Y' => EnemyKind.roller,
    'J' => EnemyKind.popper,
    _ => null,
  };

  /// 计算巡逻的左右像素边界，返回 `(leftBound, rightBound)`。
  static (double, double) boundsFor({
    required LevelData level,
    required double spawnX,
    required EnemyKind kind,
  }) {
    final tile = GameConstants.tileSize;
    final enemyTile = (spawnX / tile).round();
    var patrolLeft = enemyTile;
    var patrolRight = enemyTile;

    bool hasSafePatrolTile(int x) {
      if (x < 2 || x >= level.width - 2) {
        return false;
      }
      if (level.tileAt(x, level.height - 2) != '#' &&
          level.tileAt(x, level.height - 1) != '#') {
        return false;
      }
      if ('#=?D'.contains(level.tileAt(x, level.height - 4))) {
        return false;
      }
      for (var checkpointX = x - 1; checkpointX <= x + 1; checkpointX++) {
        if (level.tileAt(checkpointX, level.height - 3) == 'K') {
          return false;
        }
      }
      return true;
    }

    for (var offset = 1; offset <= 2; offset++) {
      if (!hasSafePatrolTile(enemyTile - offset)) {
        break;
      }
      patrolLeft = enemyTile - offset;
    }
    for (var offset = 1; offset <= 2; offset++) {
      if (!hasSafePatrolTile(enemyTile + offset)) {
        break;
      }
      patrolRight = enemyTile + offset;
    }

    final halfWidth = halfWidthOf(kind);
    double availablePatrolTravel(int otherTile, EnemyKind otherKind) {
      final otherHalfWidth = halfWidthOf(otherKind);
      final centerDistance = (enemyTile - otherTile).abs() * tile;
      final reservedSpace = halfWidth + otherHalfWidth + tile;
      return ((centerDistance - reservedSpace) / 2)
          .clamp(0.0, tile * 2)
          .toDouble();
    }

    final centerX = (enemyTile + 0.5) * tile;
    var patrolLeftX = (patrolLeft + 0.5) * tile;
    var patrolRightX = (patrolRight + 0.5) * tile;
    var nearestLeftTile = -1;
    var nearestRightTile = level.width;
    EnemyKind? leftKind;
    EnemyKind? rightKind;
    for (var x = 0; x < level.width; x++) {
      final marker = level.tileAt(x, level.height - 3);
      final otherKind = kindOfMarker(marker);
      if (otherKind == null || x == enemyTile) {
        continue;
      }
      if (x < enemyTile && x > nearestLeftTile) {
        nearestLeftTile = x;
        leftKind = otherKind;
      } else if (x > enemyTile && x < nearestRightTile) {
        nearestRightTile = x;
        rightKind = otherKind;
      }
    }
    if (leftKind case final neighborKind?) {
      patrolLeftX = math.max(
        patrolLeftX,
        centerX - availablePatrolTravel(nearestLeftTile, neighborKind),
      );
    }
    if (rightKind case final neighborKind?) {
      patrolRightX = math.min(
        patrolRightX,
        centerX + availablePatrolTravel(nearestRightTile, neighborKind),
      );
    }
    return (patrolLeftX, patrolRightX);
  }
}
