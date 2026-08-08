import 'package:flutter_test/flutter_test.dart';
import 'package:macaron_girlfriend_run/data/game_models.dart';
import 'package:macaron_girlfriend_run/data/level_catalog.dart';
import 'package:macaron_girlfriend_run/data/shop_catalog.dart';

void main() {
  test('99 levels catalog loads with spawn and goal', () {
    var count = 0;
    for (var w = 0; w < GameConstants.worldCount; w++) {
      for (var l = 0; l < GameConstants.levelsPerWorld; l++) {
        final level = LevelCatalog.load(w, l);
        expect(level.width, greaterThan(10));
        expect(level.rows.any((r) => r.contains('P')), isTrue);
        expect(level.rows.any((r) => r.contains('F')), isTrue);
        expect(level.rows.any((r) => r.contains('K')), isTrue);
        count++;
      }
    }
    expect(count, GameConstants.totalLevels);
  });

  test('boss levels contain boss tile', () {
    for (var w = 0; w < GameConstants.worldCount; w++) {
      final level = LevelCatalog.load(w, 10);
      expect(level.rows.any((r) => r.contains('B')), isTrue);
    }
  });

  test('signature levels contain handcrafted markers', () {
    for (final l in [0, 4, 7]) {
      final level = LevelCatalog.load(0, l);
      expect(
        level.rows.any((r) => r.contains('?') || r.contains('S') || r.contains('M')),
        isTrue,
      );
    }
  });

  test('time limit and enemy speed scale', () {
    final easy = GameConstants.timeLimitFor(1, mapWidth: 80);
    final hard = GameConstants.timeLimitFor(12, mapWidth: 80);
    expect(easy, greaterThan(hard));
    expect(
      GameConstants.enemySpeedFor(8),
      greaterThan(GameConstants.enemySpeedFor(1)),
    );
  });

  test('shop catalog has free default and premium skins', () {
    expect(ShopCatalog.items.first.id, ShopCatalog.defaultId);
    expect(ShopCatalog.items.first.price, 0);
    expect(ShopCatalog.of('crown').price, greaterThan(0));
    expect(ShopCatalog.of('sparkle_shoes').price, greaterThan(0));
    expect(ShopCatalog.of('strawberry_cape').price, greaterThan(0));
  });

  test('jump height can reach mid platforms from ground', () {
    final peak = (GameConstants.jumpVelocity * GameConstants.jumpVelocity) /
        (2 * GameConstants.gravity);
    expect(peak, greaterThan(GameConstants.tileSize * 5));
  });

  test('solid platforms stay in reachable band', () {
    for (var w = 0; w < GameConstants.worldCount; w++) {
      for (var l = 0; l < GameConstants.levelsPerWorld; l++) {
        final level = LevelCatalog.load(w, l);
        final highest = (level.height - 8).clamp(4, level.height - 5);
        final lowest = (level.height - 4).clamp(highest, level.height - 3);
        for (var y = 0; y < level.height; y++) {
          final row = level.rows[y];
          if (!row.contains('=') && !row.contains('?')) {
            continue;
          }
          for (var x = 0; x < row.length; x++) {
            final ch = row[x];
            if (ch == '=' || ch == '?') {
              expect(y, inInclusiveRange(highest, lowest),
                  reason: 'w$w l$l ($x,$y)=$ch');
            }
          }
        }
      }
    }
  });
}
