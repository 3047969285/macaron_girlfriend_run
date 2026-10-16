import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:macaron_girlfriend_run/data/enemy_kind.dart';
import 'package:macaron_girlfriend_run/data/game_models.dart';
import 'package:macaron_girlfriend_run/data/save_service.dart';
import 'package:macaron_girlfriend_run/game/entities/entities.dart';
import 'package:macaron_girlfriend_run/game/macaron_game.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('six skills keep distinct keyboard labels', () {
    expect(HeroSkill.values, hasLength(6));
    expect(HeroSkill.values.map((skill) => skill.keyLabel).toList(), [
      'J',
      'K',
      'Q',
      '1',
      '2',
      '3',
    ]);
    for (final skill in HeroSkill.values) {
      expect(GameConstants.skillCooldownFor(skill, 1), greaterThan(0));
    }
  });

  testWidgets('primary touch skill follows each level signature', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'sound_on': false,
      'music_on': false,
      'haptic_on': false,
    });
    await SaveService.instance.init();

    for (
      var levelIndex = 0;
      levelIndex < HeroSkill.values.length;
      levelIndex++
    ) {
      final game = MacaronGame(
        worldIndex: 0,
        levelIndex: levelIndex,
        role: PlayerRole.girlfriend,
      );
      await tester.pumpWidget(GameWidget(game: game));
      await tester.pump(const Duration(milliseconds: 100));
      expect(game.levelReady, isTrue);
      game.pauseEngine();

      final signatureSkill = HeroSkill.values[levelIndex];
      expect(game.activeSkill, signatureSkill);
      expect(game.skillButtonLabel, signatureSkill.shortLabel);
      expect(game.skillCooldownRatio, 0);

      game.activateSkill();
      expect(game.cooldownRatioOf(signatureSkill), greaterThan(0));
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('dash does not lock the other five skills', (tester) async {
    SharedPreferences.setMockInitialValues({
      'sound_on': false,
      'music_on': false,
      'haptic_on': false,
    });
    await SaveService.instance.init();
    final game = MacaronGame(
      worldIndex: 0,
      levelIndex: 0,
      role: PlayerRole.girlfriend,
    );
    await tester.pumpWidget(GameWidget(game: game));
    await tester.pump(const Duration(milliseconds: 100));
    game.pauseEngine();

    game.activateSkill(HeroSkill.dash);
    expect(game.cooldownRatioOf(HeroSkill.dash), greaterThan(0));
    expect(game.cooldownRatioOf(HeroSkill.shield), 0);
    expect(game.cooldownRatioOf(HeroSkill.airHop), 0);
    game.activateSkill(HeroSkill.shield);
    expect(game.player.isInvincible, isTrue);
    expect(game.cooldownRatioOf(HeroSkill.shield), greaterThan(0));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('air hop lifts an airborne player and pound dives', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'sound_on': false,
      'music_on': false,
      'haptic_on': false,
    });
    await SaveService.instance.init();
    final game = MacaronGame(
      worldIndex: 0,
      levelIndex: 0,
      role: PlayerRole.girlfriend,
    );
    await tester.pumpWidget(GameWidget(game: game));
    await tester.pump(const Duration(milliseconds: 100));
    game.pauseEngine();

    game.player
      ..onGround = false
      ..velocity.y = 40;
    game.activateSkill(HeroSkill.airHop);
    expect(game.player.velocity.y, lessThan(0));

    game.player.velocity.y = 0;
    game.activateSkill(HeroSkill.pound);
    expect(game.player.velocity.y, greaterThan(1000));
    expect(game.player.pounding, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a ground pound breaks shell armor a dash only chips', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'sound_on': false,
      'music_on': false,
      'haptic_on': false,
    });
    await SaveService.instance.init();
    final game = MacaronGame(
      worldIndex: 0,
      levelIndex: 0,
      role: PlayerRole.girlfriend,
    );
    await tester.pumpWidget(GameWidget(game: game));
    await tester.pump(const Duration(milliseconds: 100));
    game.pauseEngine();
    for (final enemy in List<SoftEnemy>.from(game.enemies)) {
      enemy.removeFromParent();
    }
    game.enemies.clear();

    SoftEnemy spawn(EnemyKind kind, double dx) {
      final at = game.player.position + Vector2(dx, 0);
      final enemy = SoftEnemy(
        position: at,
        leftBound: at.x,
        rightBound: at.x,
        difficulty: game.level.difficulty,
        speed: 0,
        kind: kind,
      );
      game.enemies.add(enemy);
      game.world.add(enemy);
      return enemy;
    }

    final chipped = spawn(EnemyKind.shell, 0);
    game.player.onGround = true;
    game.activateSkill(HeroSkill.dash);
    game.update(1 / 30);
    expect(chipped.dead, isFalse);
    expect(chipped.hitPoints, 1);

    chipped.removeFromParent();
    game.enemies.remove(chipped);
    final shell = spawn(EnemyKind.shell, 0);
    final bruiser = spawn(EnemyKind.bruiser, 36);
    final walker = spawn(EnemyKind.walker, 60);
    final distant = spawn(EnemyKind.shell, 180);
    game.player.onGround = true;
    game.activateSkill(HeroSkill.pound);

    expect(shell.dead, isTrue);
    expect(bruiser.dead, isTrue);
    expect(walker.dead, isTrue);
    expect(game.enemies.contains(shell), isFalse);
    expect(distant.dead, isFalse);
    expect(distant.hitPoints, 2);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
