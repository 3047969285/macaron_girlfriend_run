import 'package:flame/game.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:macaron_girlfriend_run/data/game_models.dart';
import 'package:macaron_girlfriend_run/data/save_service.dart';
import 'package:macaron_girlfriend_run/game/entities/entities.dart';
import 'package:macaron_girlfriend_run/game/macaron_game.dart';
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

  testWidgets('powered-up player pulls nearby coins but not far ones', (
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
    final center = Vector2(
      game.player.position.x,
      game.player.position.y - game.player.size.y * 0.5,
    );
    final near = MacaronCoin(position: center + Vector2(120, -40));
    final far = MacaronCoin(position: center + Vector2(400, 0));
    game.coins
      ..clear()
      ..addAll([near, far]);
    final nearStart = near.position.clone();
    final farStart = far.position.clone();

    game.player.poweredUp = false;
    game.attractCoinsForTest(0.1);
    expect(near.position, nearStart, reason: 'no pull without power-up');

    game.player.poweredUp = true;
    final before = (near.position - center).length;
    game.attractCoinsForTest(0.1);
    expect((near.position - center).length, lessThan(before));
    expect(far.position, farStart, reason: 'outside the magnet radius');

    for (var i = 0; i < 20; i++) {
      game.attractCoinsForTest(0.1);
    }
    expect((near.position - center).length, lessThan(2));
  });
}
