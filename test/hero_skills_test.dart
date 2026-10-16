import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:macaron_girlfriend_run/data/game_models.dart';
import 'package:macaron_girlfriend_run/data/save_service.dart';
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
}
