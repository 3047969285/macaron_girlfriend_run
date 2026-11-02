import 'package:flame/game.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:macaron_girlfriend_run/data/game_models.dart';
import 'package:macaron_girlfriend_run/data/save_service.dart';
import 'package:macaron_girlfriend_run/game/macaron_game.dart';
import 'package:macaron_girlfriend_run/game/player/girlfriend_player.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'sound_on': false,
      'music_on': false,
      'haptic_on': false,
    });
    await SaveService.instance.init();
  });

  testWidgets('a standing player is drawn still: grounded pose, fixed feet', (
    tester,
  ) async {
    final game = MacaronGame(
      worldIndex: 0,
      levelIndex: 0,
      role: PlayerRole.girlfriend,
    );
    await tester.pumpWidget(GameWidget(game: game));
    await tester.pump(const Duration(milliseconds: 100));
    game.pauseEngine();
    for (var i = 0; i < 60; i++) {
      game.update(1 / 60);
    }
    final player = game.player;
    final restFeet = player.position.y + player.visualLift;
    for (var i = 0; i < 180; i++) {
      game.update(1 / 60);
      expect(player.visuallyGrounded, isTrue, reason: 'pose frame $i');
      expect(
        player.position.y + player.visualLift,
        closeTo(restFeet, 0.001),
        reason: 'feet frame $i',
      );
    }
  });

  test('a real fall or jump is not hidden by the stabiliser', () {
    final player = GirlfriendPlayer(role: PlayerRole.girlfriend)
      ..onGround = true;
    player.update(1 / 60);
    // 起跳：向上的速度立刻视为离地。
    player
      ..onGround = false
      ..velocity.setValues(0, -500);
    expect(player.visuallyGrounded, isFalse);
    // 走下平台：下沉超过 4.5 像素后不再算落地。
    player.velocity.setValues(0, 120);
    player.position.y += 10;
    expect(player.visuallyGrounded, isFalse);
    // 离地超过缓冲时间后不再算落地。
    player.position.y -= 10;
    for (var i = 0; i < 20; i++) {
      player.update(1 / 60);
    }
    expect(player.visuallyGrounded, isFalse);
  });
}
