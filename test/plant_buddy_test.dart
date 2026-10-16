import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:macaron_girlfriend_run/data/enemy_kind.dart';
import 'package:macaron_girlfriend_run/data/game_models.dart';
import 'package:macaron_girlfriend_run/data/save_service.dart';
import 'package:macaron_girlfriend_run/game/entities/entities.dart';
import 'package:macaron_girlfriend_run/game/macaron_game.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<MacaronGame> _loadGame(WidgetTester tester, {bool boss = false}) async {
  final game = MacaronGame(
    worldIndex: 0,
    levelIndex: boss ? GameConstants.levelsPerWorld - 1 : 0,
    role: PlayerRole.girlfriend,
  );
  await tester.pumpWidget(GameWidget(game: game));
  await tester.pump(const Duration(milliseconds: 100));
  expect(game.levelReady, isTrue);
  game.pauseEngine();
  for (final enemy in List<SoftEnemy>.from(game.enemies)) {
    enemy.removeFromParent();
  }
  game.enemies.clear();
  for (var frame = 0; frame < 25; frame++) {
    game.update(1 / 30);
  }
  return game;
}

SoftEnemy _enemy(Vector2 at, {EnemyKind kind = EnemyKind.walker}) => SoftEnemy(
  position: at,
  leftBound: at.x,
  rightBound: at.x,
  difficulty: 1,
  speed: 0,
  kind: kind,
);

Iterable<PlayerCandyShot> _peas(MacaronGame game) => game.world.children
    .whereType<PlayerCandyShot>()
    .where((shot) => shot.isPea && !shot.spent);

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'sound_on': false,
      'music_on': false,
      'haptic_on': false,
    });
    await SaveService.instance.init();
  });

  testWidgets('plant buddy aims at a body and defeats its visible target', (
    tester,
  ) async {
    final game = await _loadGame(tester);
    final enemy = _enemy(game.player.position + Vector2(180, 0));
    game.enemies.add(enemy);
    game.world.add(enemy);
    game.player.cosmeticId = 'pea_buddy';

    game.update(1 / 30);
    game.update(0);

    final shot = _peas(game).single;
    final expected =
        enemy.position - Vector2(0, enemy.size.y / 2) - shot.position;
    expected.normalize();
    expect((shot.direction - expected).length, lessThan(0.001));
    for (var frame = 0; frame < 30 && !enemy.dead; frame++) {
      game.update(1 / 30);
    }
    expect(enemy.dead, isTrue);
    expect(game.kills, 1);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('plant buddy waits behind terrain and can choose a clear lane', (
    tester,
  ) async {
    for (final clearTarget in [false, true]) {
      final game = await _loadGame(tester);
      final groundY = (game.level.height - 2) * GameConstants.tileSize;
      final wall = game.terrain
          .firstWhere(
            (tile) =>
                tile.rect.left == GameConstants.tileSize * 6 &&
                tile.rect.bottom <= groundY - GameConstants.tileSize,
          )
          .rect;
      final origin = Vector2(wall.left - 60, wall.center.dy);
      game.player
        ..position.setValues(origin.x, origin.y + game.player.hitHeight * 0.98)
        ..velocity.setZero()
        ..onGround = false
        ..cosmeticId = 'pea_buddy';
      final hidden = _enemy(Vector2(wall.right + 144, origin.y + 18));
      final visible = _enemy(Vector2(origin.x - 120, origin.y + 18));
      final targets = [hidden, if (clearTarget) visible];
      game.enemies.addAll(targets);
      game.world.addAll(targets);

      game.update(1 / 30);
      game.update(0);

      expect(_peas(game), hasLength(clearTarget ? 1 : 0));
      if (clearTarget) {
        expect(_peas(game).single.direction.x, lessThan(0));
      }
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('a curled shell provides cover until its guard opens', (
    tester,
  ) async {
    final game = await _loadGame(tester);
    final shell =
        _enemy(game.player.position + Vector2(100, 0), kind: EnemyKind.shell)
          ..targetX = game.player.position.x
          ..targetY = game.player.position.y;
    for (var frame = 0; frame < 200 && !shell.isGuarding; frame++) {
      shell.update(0.05);
    }
    expect(shell.isGuarding, isTrue);
    final behind = _enemy(game.player.position + Vector2(200, 0));
    game.enemies.addAll([shell, behind]);
    game.world.addAll([shell, behind]);
    game.player.cosmeticId = 'pea_buddy';

    game.update(1 / 30);
    game.update(0);
    expect(_peas(game), isEmpty);
    for (var frame = 0; frame < 80 && shell.hitPoints == 2; frame++) {
      game.update(1 / 30);
    }

    expect(shell.hitPoints, 1);
    expect(behind.dead, isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('plant buddy counters a boss only while the shot can arrive', (
    tester,
  ) async {
    for (final shortWindow in [false, true]) {
      final game = await _loadGame(tester, boss: true);
      final boss = game.boss!;
      game.player
        ..position.setFrom(boss.position - Vector2(120, 0))
        ..velocity.setZero()
        ..onGround = true
        ..invincibleTimer = 2;
      boss
        ..targetX = game.player.position.x
        ..stompHit();
      boss.update(0.2);
      expect(boss.canReceiveProjectile, isTrue);
      if (shortWindow) {
        boss.update(boss.projectileWindowRemaining - 0.1);
      }
      game.player.cosmeticId = 'pea_buddy';
      final health = boss.hp;

      game.update(1 / 30);
      game.update(0);
      expect(_peas(game), hasLength(shortWindow ? 0 : 1));
      if (!shortWindow) {
        for (var frame = 0; frame < 30 && boss.hp == health; frame++) {
          game.update(1 / 30);
        }
        expect(boss.hp, health - 1);
      }
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('plant peas leave the last armor layer for the gun', (
    tester,
  ) async {
    final game = await _loadGame(tester);
    final shell =
        _enemy(game.player.position + Vector2(100, 0), kind: EnemyKind.shell)
          ..targetX = game.player.position.x
          ..targetY = game.player.position.y;
    for (var frame = 0; frame < 200 && !shell.isGuarding; frame++) {
      shell.update(0.05);
    }
    expect(shell.isGuarding, isTrue);
    final behind = _enemy(game.player.position + Vector2(220, 0));
    game.enemies.addAll([shell, behind]);
    game.world.addAll([shell, behind]);
    game.player
      ..cosmeticId = 'pea_buddy'
      ..invincibleTimer = 30;

    for (var frame = 0; frame < 160 && shell.hitPoints == 2; frame++) {
      game.update(1 / 30);
    }
    expect(shell.hitPoints, 1);

    for (var frame = 0; frame < 120; frame++) {
      game.update(1 / 30);
    }
    expect(shell.hitPoints, 1);
    expect(shell.dead, isFalse);
    expect(behind.dead, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a gun removes the armor layer a plant pea leaves', (
    tester,
  ) async {
    final game = await _loadGame(tester);
    final shell = _enemy(
      game.player.position + Vector2(90, 0),
      kind: EnemyKind.shell,
    );
    expect(shell.takeStomp(), isFalse);
    expect(shell.hitPoints, 1);
    game.enemies.add(shell);
    game.world.add(shell);
    game.player
      ..facingRight = true
      ..invincibleTimer = 2;
    game
      ..gunTimer = 2
      ..setShootPressed(true);
    for (var frame = 0; frame < 20 && !shell.dead; frame++) {
      game.update(1 / 30);
    }
    expect(shell.dead, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a gun swats thrown candy and a plant pea lets it pass', (
    tester,
  ) async {
    for (final useGun in [false, true]) {
      final game = MacaronGame(
        worldIndex: 0,
        levelIndex: 0,
        role: PlayerRole.girlfriend,
      );
      await tester.pumpWidget(GameWidget(game: game));
      await tester.pump(const Duration(milliseconds: 100));
      expect(game.levelReady, isTrue);
      game.pauseEngine();
      final walker = game.enemies.firstWhere(
        (enemy) => enemy.kind == EnemyKind.walker,
      );
      for (final enemy in List<SoftEnemy>.from(game.enemies)) {
        if (enemy == walker) {
          continue;
        }
        enemy.removeFromParent();
        game.enemies.remove(enemy);
      }

      EnemyCandyShot? thrown;
      for (var frame = 0; frame < 240 && thrown == null; frame++) {
        game.player
          ..position.setFrom(walker.position + Vector2(-140, 0))
          ..velocity.setZero()
          ..onGround = true
          ..facingRight = true
          ..invincibleTimer = 8;
        walker.simActive = true;
        game.update(1 / 30);
        final shots = game.world.children
            .whereType<EnemyCandyShot>()
            .where((shot) => !shot.spent);
        if (shots.isNotEmpty) {
          thrown = shots.first;
        }
      }
      expect(thrown, isNotNull);

      final muzzle =
          game.player.position +
          Vector2(22, -game.player.hitHeight * 0.58);
      final travel = GameConstants.enemyProjectileSpeedFor(
        game.level.difficulty,
      );
      thrown!.position.setFrom(muzzle + Vector2(travel / 30 + 12, -14));
      game.player.invincibleTimer = 8;
      if (useGun) {
        game
          ..gunTimer = 2
          ..setShootPressed(true);
      } else {
        game.player.cosmeticId = 'pea_buddy';
      }
      game.update(1 / 30);

      expect(thrown.spent, useGun);
      expect(game.player.dead, isFalse);
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });
}
