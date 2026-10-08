import 'package:flame/game.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:macaron_girlfriend_run/data/enemy_kind.dart';
import 'package:macaron_girlfriend_run/data/game_models.dart';
import 'package:macaron_girlfriend_run/data/level_catalog.dart';
import 'package:macaron_girlfriend_run/data/save_service.dart';
import 'package:macaron_girlfriend_run/data/shop_catalog.dart';
import 'package:macaron_girlfriend_run/game/entities/entities.dart';
import 'package:macaron_girlfriend_run/game/macaron_game.dart';
import 'package:macaron_girlfriend_run/game/player/girlfriend_player.dart';

void main() {
  test(
    'active skill changes between levels and every world has all skills',
    () {
      for (var world = 0; world < GameConstants.worldCount; world++) {
        final skills = <HeroSkill>{};
        for (var level = 0; level < GameConstants.levelsPerWorld; level++) {
          final skill = GameConstants.heroSkillForLevel(world, level);
          skills.add(skill);
          if (level + 1 < GameConstants.levelsPerWorld) {
            expect(
              skill,
              isNot(GameConstants.heroSkillForLevel(world, level + 1)),
              reason:
                  'world $world, level $level must rotate its active skill',
            );
          }
        }
        expect(skills, HeroSkill.values.toSet(), reason: 'world $world');
      }
    },
  );

  test('99 levels catalog loads with spawn and goal', () {
    var count = 0;
    var trapperCount = 0;
    var gardenEventCount = 0;
    var levelsWithDuckTunnel = 0;
    var levelsWithGun = 0;
    var levelsWithVehicle = 0;
    final pickupPatterns = <String>{};
    for (var w = 0; w < GameConstants.worldCount; w++) {
      for (var l = 0; l < GameConstants.levelsPerWorld; l++) {
        final level = LevelCatalog.load(w, l);
        final map = level.rows.join();
        trapperCount += map.split('T').length - 1;
        gardenEventCount += map.contains('N') ? 1 : 0;
        levelsWithDuckTunnel += map.contains('D') ? 1 : 0;
        levelsWithGun += map.contains('W') ? 1 : 0;
        levelsWithVehicle += map.contains('V') ? 1 : 0;
        pickupPatterns.add(['S', 'N', 'W', 'V'].where(map.contains).join());
        expect(level.width, greaterThanOrEqualTo(130));
        expect(level.rows.any((r) => r.contains('P')), isTrue);
        expect(level.rows.any((r) => r.contains('F')), isTrue);
        expect(level.rows.any((r) => r.contains('K')), isTrue);
        count++;
      }
    }
    expect(count, GameConstants.totalLevels);
    expect(trapperCount, greaterThan(0));
    expect(gardenEventCount, greaterThan(GameConstants.totalLevels ~/ 2));
    expect(levelsWithDuckTunnel, GameConstants.totalLevels);
    expect(levelsWithGun, greaterThan(GameConstants.totalLevels * 2 ~/ 3));
    expect(levelsWithVehicle, greaterThan(GameConstants.totalLevels * 2 ~/ 3));
    expect(pickupPatterns.length, greaterThanOrEqualTo(4));
    expect(LevelCatalog.load(8, 10).width, 454);
  });

  test('every level is unique and has a traversable ground route', () {
    final signatures = <String>{};
    final tunnelLengths = <int>{};
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
          GirlfriendPlayer.duckHeight,
          lessThan(GameConstants.tileSize),
          reason: '$reason crouch must fit beneath the tunnel',
        );
        expect(
          GirlfriendPlayer.standHeight,
          greaterThan(GameConstants.tileSize),
          reason: '$reason standing must not fit beneath the tunnel',
        );
        expect(
          level.rows.join().split('K').length - 1,
          greaterThanOrEqualTo(4),
          reason: '$reason needs frequent checkpoints',
        );

        final ground = level.height - 3;
        final tunnelTiles = [
          for (var x = 2; x <= level.width - 3; x++)
            if (level.tileAt(x, ground - 1) == 'D') x,
        ];
        expect(
          tunnelTiles.length,
          inInclusiveRange(4, 6),
          reason: reason,
        );
        expect(
          tunnelTiles.any((x) => level.tileAt(x, ground) == 'C'),
          isTrue,
          reason: '$reason tunnel needs an optional candy reward',
        );
        tunnelLengths.add(tunnelTiles.length);
        expect(
          tunnelTiles.last - tunnelTiles.first + 1,
          tunnelTiles.length,
          reason: '$reason tunnel roof must be continuous',
        );
        for (final x in tunnelTiles) {
          expect(level.tileAt(x, ground + 1), '#', reason: reason);
          expect(
            'PFEGRBTWV'.contains(level.tileAt(x, ground)),
            isFalse,
            reason: '$reason tunnel must not be blocked by enemies or exit',
          );
        }
        for (var y = 0; y < level.height; y++) {
          for (var x = 0; x < level.width; x++) {
            if (level.tileAt(x, y) != 'T') {
              continue;
            }
            expect(y, ground, reason: '$reason places trapper on ground');
            expect(level.tileAt(x, ground + 1), '#', reason: reason);
            expect(level.tileAt(x, ground + 2), '#', reason: reason);
          }
        }
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
            .where((tile) => 'EGRBT'.contains(tile))
            .length;
        final walkSpeed = GameConstants.playerMoveSpeedFor(
          GameConstants.maxDifficulty,
        );
        final tunnelDistance = tunnelTiles.length * GameConstants.tileSize;
        final tunnelSlowdown =
            (tunnelDistance + GirlfriendPlayer.standWidth) /
                (walkSpeed * GameConstants.duckMoveSpeedMultiplier) -
            tunnelDistance / walkSpeed;
        final conservativeClearTime =
            level.width * GameConstants.tileSize / walkSpeed +
            tunnelSlowdown +
            (gapCount + enemyCount) * fullJumpTime;
        expect(
          GameConstants.timeLimitFor(level.difficulty, mapWidth: level.width),
          greaterThan(conservativeClearTime),
          reason: '$reason has insufficient clear time',
        );
      }
    }
    expect(signatures.length, GameConstants.totalLevels);
    expect(tunnelLengths.length, 3);
  });

  test('boss levels contain boss tile', () {
    for (var w = 0; w < GameConstants.worldCount; w++) {
      final level = LevelCatalog.load(w, 10);
      expect(level.rows.any((r) => r.contains('B')), isTrue);
    }
  });

  test('boss attack patterns rotate by world', () {
    final patterns = List.generate(
      GameConstants.worldCount,
      BossAttackPattern.forWorld,
    );
    expect(patterns.toSet(), BossAttackPattern.values.toSet());
    for (var world = 0; world < GameConstants.worldCount; world++) {
      expect(
        BossAttackPattern.forWorld(world),
        BossAttackPattern.values[world % BossAttackPattern.values.length],
      );
    }
  });

  test('enraged bosses announce and execute their world attack', () {
    for (var world = 0; world < BossAttackPattern.values.length; world++) {
      final shotDirections = <double>[];
      final trapPositions = <Vector2>[];
      final boss = MacaronBoss(
        position: Vector2(200, 120),
        leftBound: 0,
        rightBound: 400,
        worldIndex: world,
        onShoot: (_, direction) => shotDirections.add(direction),
        onLayTrap: trapPositions.add,
      )..targetX = 300;
      boss.stompHit();

      boss.update(0.2);
      expect(
        boss.isSlamming ||
            boss.isPouncing ||
            boss.isRushing ||
            shotDirections.isNotEmpty ||
            trapPositions.isNotEmpty,
        isFalse,
      );
      var elapsed = 0.0;
      while (!boss.isSlamming &&
          !boss.isPouncing &&
          !boss.isRushing &&
          shotDirections.isEmpty &&
          trapPositions.isEmpty &&
          elapsed < 2) {
        boss.update(0.05);
        elapsed += 0.05;
      }
      expect(elapsed, lessThan(2));
      switch (boss.attackPattern) {
        case BossAttackPattern.slam:
          expect(boss.isSlamming, isTrue);
        case BossAttackPattern.rush:
          expect(boss.isRushing, isTrue);
        case BossAttackPattern.volley:
          expect(shotDirections, [1]);
        case BossAttackPattern.pounce:
          expect(boss.isPouncing, isTrue);
        case BossAttackPattern.trap:
          expect(trapPositions, hasLength(1));
          expect(trapPositions.single.x, 300);
          expect(trapPositions.single.y, 120);
        case BossAttackPattern.doubleRush:
          expect(boss.isRushing, isTrue);
        case BossAttackPattern.slamVolley:
          expect(boss.isSlamming, isTrue);
          for (var frame = 0; frame < 20 && shotDirections.isEmpty; frame++) {
            boss.update(0.05);
          }
          expect(shotDirections, [1]);
        case BossAttackPattern.trapVolley:
          expect(trapPositions, hasLength(1));
          for (var frame = 0; frame < 20 && shotDirections.isEmpty; frame++) {
            boss.update(0.05);
          }
          expect(shotDirections, [1]);
        case BossAttackPattern.longVolley:
          for (var shot = 0; shot < 4; shot++) {
            boss.update(0.31);
          }
          expect(shotDirections, hasLength(5));
      }
    }
  });

  test('enemy skill cues match each attack and allow a warning window', () {
    for (final kind in EnemyKind.values) {
      final cues = <EnemyKind>[];
      var shots = 0;
      var traps = 0;
      final enemy = SoftEnemy(
        position: Vector2(200, 120),
        leftBound: 0,
        rightBound: 400,
        difficulty: 1,
        kind: kind,
        onSkillCue: (_, skill) => cues.add(skill),
        onShoot: (_, _) => shots++,
        onLayTrap: (_) => traps++,
      )..targetX = 320;
      enemy.targetY = 120;

      for (var frame = 0; frame < 140 && cues.isEmpty; frame++) {
        enemy.update(0.05);
      }
      expect(cues, [kind]);
      expect(shots, 0);
      expect(traps, 0);

      final warningFrames = (GameConstants.enemySkillWarningFor(1, kind) / 0.05)
          .ceil();
      for (var frame = 0; frame < warningFrames; frame++) {
        enemy.update(0.05);
      }
      switch (kind) {
        case EnemyKind.walker:
          expect(shots, 1);
        case EnemyKind.hopper:
          expect(enemy.position.y, lessThan(120));
        case EnemyKind.bruiser:
          final beforeCharge = enemy.position.x;
          enemy.update(0.05);
          expect(enemy.position.x, greaterThan(beforeCharge));
        case EnemyKind.trapper:
          expect(traps, 1);
      }
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

  testWidgets(
    'all 99 levels build in the live Flame game runtime',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'sound_on': false,
        'music_on': false,
        'haptic_on': false,
      });
      await SaveService.instance.init();

      for (var world = 0; world < GameConstants.worldCount; world++) {
        for (var level = 0; level < GameConstants.levelsPerWorld; level++) {
          final game = MacaronGame(
            worldIndex: world,
            levelIndex: level,
            role: PlayerRole.girlfriend,
          );
          await tester.pumpWidget(GameWidget(game: game));
          await tester.pump(const Duration(milliseconds: 100));
          final catalogLevel = LevelCatalog.load(world, level);
          final map = catalogLevel.rows.join();
          int markerCount(String marker) => map.split(marker).length - 1;
          final enemyMarkers =
              markerCount('E') +
              markerCount('G') +
              markerCount('R') +
              markerCount('T');
          final expectedTerrain = map
              .split('')
              .where((tile) => '#=D?'.contains(tile))
              .length;

          expect(game.levelReady, isTrue, reason: 'w$world l$level loads');
          expect(
            game.level.width,
            catalogLevel.width,
            reason: 'w$world l$level',
          );
          expect(game.goal, isNotNull, reason: 'w$world l$level has an exit');
          expect(
            game.terrain,
            hasLength(expectedTerrain),
            reason: 'w$world l$level terrain is built',
          );
          expect(
            game.enemies,
            hasLength(enemyMarkers.clamp(0, GameConstants.maxActiveEnemies)),
            reason: 'w$world l$level enemies are built',
          );
          expect(
            game.checkpoints,
            hasLength(markerCount('K')),
            reason: 'w$world l$level checkpoints are built',
          );
          expect(game.coins, hasLength(markerCount('C').clamp(0, 96)));
          expect(game.blocks, hasLength(markerCount('?')));
          expect(game.powers, hasLength(markerCount('M')));
          expect(game.gunPickups, hasLength(markerCount('W')));
          expect(game.peaSeeds, hasLength(markerCount('N')));
          expect(game.vehiclePickups, hasLength(markerCount('V')));
          expect(game.hearts, hasLength(markerCount('H')));
          expect(game.springs, hasLength(markerCount('S')));
          expect(
            game.timeLeft,
            closeTo(
              GameConstants.timeLimitFor(
                catalogLevel.difficulty,
                mapWidth: catalogLevel.width,
              ),
              0.001,
            ),
            reason: 'w$world l$level time budget',
          );
          expect(
            game.boss != null,
            level == GameConstants.levelsPerWorld - 1,
            reason: 'w$world l$level boss configuration',
          );
          game.pauseEngine();
          await tester.pumpWidget(const SizedBox.shrink());
        }
      }
    },
    timeout: const Timeout(Duration(minutes: 10)),
  );

  testWidgets('starter level clears through live movement and collision', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'sound_on': false,
      'music_on': false,
      'haptic_on': false,
    });
    await SaveService.instance.init();

    LevelResult? result;
    final game = MacaronGame(
      worldIndex: 0,
      levelIndex: 0,
      role: PlayerRole.girlfriend,
      onWin: (value) => result = value,
    );
    await tester.pumpWidget(GameWidget(game: game));
    await tester.pump(const Duration(milliseconds: 100));
    expect(game.levelReady, isTrue);
    game
      ..pauseEngine()
      ..onGameResize(Vector2(960, 540));

    final ground = game.level.height - 3;
    final tunnel = [
      for (var x = 0; x < game.level.width; x++)
        if (game.level.tileAt(x, ground - 1) == 'D') x,
    ];
    final tunnelStart = tunnel.first * GameConstants.tileSize;
    final tunnelEnd = (tunnel.last + 1) * GameConstants.tileSize;
    final maxFrames =
        (GameConstants.timeLimitFor(
              game.level.difficulty,
              mapWidth: game.level.width,
            ) +
            120) *
        30;

    for (var frame = 0; frame < maxFrames && result == null; frame++) {
      final x = game.player.position.x;
      final ducking =
          x + GirlfriendPlayer.standWidth >= tunnelStart - 48 &&
          x <= tunnelEnd + GirlfriendPlayer.standWidth;
      final finalApproach = x >= game.goal!.position.x - 440;
      game
        ..rightPressed = true
        ..runPressed = true
        ..setDuckPressed(ducking)
        ..setJumpHeld(false);
      if (!ducking && !finalApproach) {
        game.setJumpHeld(true);
      }
      if (game.skillCooldownRatio == 0) {
        game.activateSkill();
      }
      game.setShootPressed(true);
      game.update(1 / 30);
    }

    expect(
      result?.cleared,
      isTrue,
      reason: 'starter level must be completable',
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
