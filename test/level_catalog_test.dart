import 'package:flutter_test/flutter_test.dart';
import 'package:macaron_girlfriend_run/data/game_models.dart';
import 'package:macaron_girlfriend_run/data/level_catalog.dart';
import 'package:macaron_girlfriend_run/data/shop_catalog.dart';
import 'package:macaron_girlfriend_run/game/player/girlfriend_player.dart';

void main() {
  test('99 levels catalog loads with spawn and goal', () {
    var count = 0;
    for (var w = 0; w < GameConstants.worldCount; w++) {
      for (var l = 0; l < GameConstants.levelsPerWorld; l++) {
        final level = LevelCatalog.load(w, l);
        expect(level.width, greaterThanOrEqualTo(100));
        expect(level.rows.any((r) => r.contains('P')), isTrue);
        expect(level.rows.any((r) => r.contains('F')), isTrue);
        expect(level.rows.any((r) => r.contains('K')), isTrue);
        count++;
      }
    }
    expect(count, GameConstants.totalLevels);
    expect(LevelCatalog.load(8, 10).width, 352);
  });

  test('every level is unique and has a traversable ground route', () {
    final signatures = <String>{};
    final minJumpRange =
        GameConstants.playerMoveSpeedFor(GameConstants.maxDifficulty) *
        2 *
        GameConstants.playerJumpVelocityFor(GameConstants.maxDifficulty).abs() /
        GameConstants.gravity;
    final maxGapDistance =
        2 * GameConstants.tileSize + GirlfriendPlayer.standWidth * 0.65;
    expect(minJumpRange, greaterThan(maxGapDistance));
    final fullJumpTime =
        2 *
        GameConstants.playerJumpVelocityFor(GameConstants.maxDifficulty).abs() /
        GameConstants.gravity;

    for (var w = 0; w < GameConstants.worldCount; w++) {
      for (var l = 0; l < GameConstants.levelsPerWorld; l++) {
        final level = LevelCatalog.load(w, l);
        final reason = 'world $w, level $l';
        expect(signatures.add(level.rows.join('\n')), isTrue, reason: reason);
        expect(
          level.rows.join().split('K').length - 1,
          greaterThanOrEqualTo(4),
          reason: '$reason needs frequent checkpoints',
        );

        final ground = level.height - 3;
        expect(level.tileAt(2, ground), 'P', reason: reason);
        expect(level.tileAt(level.width - 3, ground), 'F', reason: reason);
        expect(level.tileAt(2, ground + 1), '#', reason: reason);
        expect(level.tileAt(2, ground + 2), '#', reason: reason);
        expect(level.tileAt(level.width - 3, ground + 1), '#', reason: reason);
        expect(level.tileAt(level.width - 3, ground + 2), '#', reason: reason);

        var gapTiles = 0;
        var landingTiles = 2;
        var gapCount = 0;
        for (var x = 2; x <= level.width - 3; x++) {
          final isGap =
              level.tileAt(x, ground + 1) == ' ' &&
              level.tileAt(x, ground + 2) == ' ';
          if (isGap) {
            if (gapTiles == 0) {
              expect(landingTiles, greaterThanOrEqualTo(2), reason: reason);
              gapCount++;
            }
            gapTiles++;
            expect(gapTiles, lessThanOrEqualTo(2), reason: reason);
            landingTiles = 0;
          } else {
            expect(
              level.tileAt(x, ground + 1) == '#' ||
                  level.tileAt(x, ground + 2) == '#',
              isTrue,
              reason: '$reason has unsupported ground at x=$x',
            );
            gapTiles = 0;
            landingTiles++;
          }

          expect(
            '=?'.contains(level.tileAt(x, ground - 1)),
            isFalse,
            reason: '$reason has a low solid block at x=$x',
          );
        }

        final enemyCount = level.rows
            .join()
            .split('')
            .where((tile) => 'EGRB'.contains(tile))
            .length;
        final conservativeClearTime =
            level.width *
                GameConstants.tileSize /
                GameConstants.playerMoveSpeedFor(GameConstants.maxDifficulty) +
            (gapCount + enemyCount) * fullJumpTime;
        expect(
          GameConstants.timeLimitFor(level.difficulty, mapWidth: level.width),
          greaterThan(conservativeClearTime),
          reason: '$reason has insufficient clear time',
        );
      }
    }
    expect(signatures.length, GameConstants.totalLevels);
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
        level.rows.any(
          (r) => r.contains('?') || r.contains('S') || r.contains('M'),
        ),
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
    final peak =
        (GameConstants.jumpVelocity * GameConstants.jumpVelocity) /
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
              expect(
                y,
                inInclusiveRange(highest, lowest),
                reason: 'w$w l$l ($x,$y)=$ch',
              );
            }
          }
        }
      }
    }
  });
}
