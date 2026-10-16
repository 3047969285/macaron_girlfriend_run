import 'package:flame/game.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:macaron_girlfriend_run/data/enemy_kind.dart';
import 'package:macaron_girlfriend_run/data/game_models.dart';
import 'package:macaron_girlfriend_run/data/save_service.dart';
import 'package:macaron_girlfriend_run/game/entities/entities.dart';
import 'package:macaron_girlfriend_run/game/macaron_game.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<MacaronGame> _loadCar(WidgetTester tester) async {
  final game = MacaronGame(
    worldIndex: 0,
    levelIndex: 0,
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
  for (var frame = 0; frame < 20; frame++) {
    game.update(1 / 30);
  }
  game
    ..vehicleTimer = 8
    ..rightPressed = true
    ..runPressed = true
    ..setDuckPressed(true);
  return game;
}

void _charge(MacaronGame game, {int frames = 24}) {
  for (var frame = 0; frame < frames; frame++) {
    game.update(1 / 30);
  }
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'sound_on': false,
      'music_on': false,
      'haptic_on': false,
    });
    await SaveService.instance.init();
  });

  testWidgets('car braking charges a cancellable boost without forced motion', (
    tester,
  ) async {
    final game = await _loadCar(tester);
    final cruisingSpeed =
        GameConstants.playerRunSpeedFor(game.level.difficulty) *
        GameConstants.playerVehicleSpeedMultiplierFor(game.level.difficulty);
    _charge(game);
    expect(game.vehicleChargeRatio, greaterThan(0.95));
    expect(game.vehicleBoosting, isFalse);
    expect(game.player.velocity.x, lessThan(cruisingSpeed));

    game.setDuckPressed(false);
    game.update(1 / 30);
    expect(game.vehicleBoosting, isTrue);
    expect(game.player.vehicleBoosting, isTrue);
    expect(game.player.velocity.x, greaterThan(cruisingSpeed));
    expect(game.vehicleChargeRatio, 0);

    game.rightPressed = false;
    game.update(1 / 30);
    expect(game.player.velocity.x, 0);
    game.setDuckPressed(true);
    game.update(1 / 30);
    expect(game.vehicleBoosting, isFalse);
    expect(game.vehicleChargeRatio, 0);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a charge cannot launch in the air or outlive the car', (
    tester,
  ) async {
    for (final expire in [false, true]) {
      final game = await _loadCar(tester);
      _charge(game, frames: 12);
      expect(
        game.vehicleChargeRatio,
        greaterThan(GameConstants.vehicleMinCharge),
      );
      if (expire) {
        game.vehicleTimer = 0.01;
      } else {
        game.player
          ..position.y -= 100
          ..onGround = false
          ..coyoteTimer = 0
          ..velocity.setZero();
      }
      game.setDuckPressed(false);
      game.update(1 / 30);

      expect(game.vehicleChargeRatio, 0);
      expect(game.vehicleBoosting, isFalse);
      expect(game.player.vehicleBoosting, isFalse);
      expect(
        game.player.velocity.x,
        closeTo(GameConstants.playerRunSpeedFor(game.level.difficulty), 0.01),
      );
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('losing the car to a hit clears its stored boost', (
    tester,
  ) async {
    final game = await _loadCar(tester);
    _charge(game);
    game.setDuckPressed(false);
    game.update(1 / 30);
    expect(game.vehicleBoosting, isTrue);
    game.player
      ..position.y -= 100
      ..onGround = false
      ..coyoteTimer = 0
      ..velocity.setZero()
      ..invincibleTimer = 0;
    final at = game.player.position + Vector2(20, 0);
    final enemy = SoftEnemy(
      position: at,
      leftBound: at.x,
      rightBound: at.x,
      difficulty: game.level.difficulty,
      speed: 0,
    );
    game.enemies.add(enemy);
    game.world.add(enemy);

    game.update(1 / 30);

    expect(game.vehicleTimer, 0);
    expect(game.vehicleBoosting, isFalse);
    expect(game.player.vehicleBoosting, isFalse);
    expect(game.player.dead, isFalse);
    expect(game.player.isInvincible, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('only a charged boost crushes shell armor', (tester) async {
    for (final boost in [false, true]) {
      final game = await _loadCar(tester);
      if (boost) {
        _charge(game);
        game.setDuckPressed(false);
      } else {
        game.setDuckPressed(false);
      }
      game.update(1 / 30);
      expect(game.vehicleBoosting, boost);
      final shell = SoftEnemy(
        position: game.player.position.clone(),
        leftBound: game.player.position.x,
        rightBound: game.player.position.x,
        difficulty: game.level.difficulty,
        speed: 0,
        kind: EnemyKind.shell,
      );
      game.enemies.add(shell);
      game.world.add(shell);

      game.update(1 / 30);

      expect(game.vehicleTimer, greaterThan(0));
      expect(game.player.dead, isFalse);
      if (boost) {
        expect(shell.dead, isTrue);
        expect(game.enemies, isEmpty);
      } else {
        expect(shell.dead, isFalse);
        expect(shell.hitPoints, 1);
        expect(game.player.velocity.x, lessThan(0));
        expect(game.player.isInvincible, isTrue);
      }
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });
}
