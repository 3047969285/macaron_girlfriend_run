import 'package:flutter/widgets.dart';

import 'package:flame/game.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:macaron_girlfriend_run/data/game_models.dart';
import 'package:macaron_girlfriend_run/data/save_service.dart';
import 'package:macaron_girlfriend_run/game/macaron_game.dart';
import 'package:shared_preferences/shared_preferences.dart';

double variance(List<double> values) {
  final mean = values.reduce((a, b) => a + b) / values.length;
  return values.fold<double>(0, (s, x) => s + (x - mean) * (x - mean)) /
      values.length;
}

void main() {
  testWidgets('game physics stays smooth during steady running', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'sound_on': false,
      'music_on': false,
      'haptic_on': false,
    });
    await SaveService.instance.init();
    for (final fps in [30, 60, 120]) {
      final game = MacaronGame(
        worldIndex: 0,
        levelIndex: 0,
        role: PlayerRole.girlfriend,
      );
      await tester.pumpWidget(GameWidget(game: game, key: ValueKey(fps)));
      await tester.pump(const Duration(milliseconds: 100));
      game.pauseEngine();
      for (final enemy in List.of(game.enemies)) {
        enemy.removeFromParent();
      }
      game.enemies.clear();
      game.rightPressed = true;
      for (var i = 0; i < fps; i++) {
        game.update(1 / fps);
      }
      final playerSteps = <double>[];
      final cameraSteps = <double>[];
      for (var i = 0; i < fps ~/ 3; i++) {
        final x = game.player.position.x;
        final cx = game.camera.viewfinder.position.x;
        game.update(1 / fps);
        playerSteps.add(game.player.position.x - x);
        cameraSteps.add(game.camera.viewfinder.position.x - cx);
      }
      // ignore: avoid_print
      print(
        'physics $fps FPS player=${variance(playerSteps)} camera=${variance(cameraSteps)} travel=${playerSteps.reduce((a, b) => a + b)}',
      );
      expect(playerSteps.reduce((a, b) => a + b), greaterThan(5));
      expect(variance(playerSteps), lessThan(0.01));
      expect(variance(cameraSteps), lessThan(0.01));
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });
  testWidgets(
    'uniform player and camera motion have low frame displacement variance',
    (tester) async {
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
      for (final fps in [30, 60, 120]) {
        game.player.position.x = 400;
        game.player.facingRight = true;
        for (var i = 0; i < fps * 2; i++) {
          game.player.position.x += 50 / fps;
          game.updateCameraForTesting(1 / fps);
        }
        final playerSteps = <double>[];
        final cameraSteps = <double>[];
        for (var i = 0; i < fps; i++) {
          final x = game.player.position.x;
          final cx = game.camera.viewfinder.position.x;
          game.player.position.x += 50 / fps;
          game.updateCameraForTesting(1 / fps);
          playerSteps.add(game.player.position.x - x);
          cameraSteps.add(game.camera.viewfinder.position.x - cx);
        }
        final pv = variance(playerSteps);
        final cv = variance(cameraSteps);
        // ignore: avoid_print
        print('motion $fps FPS player=$pv camera=$cv');
        expect(pv, lessThan(0.01));
        expect(cv, lessThan(0.01));
        expect(cameraSteps.reduce((a, b) => a + b).abs(), greaterThan(20));
      }
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
