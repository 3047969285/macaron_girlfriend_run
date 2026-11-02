import 'package:flame/game.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:macaron_girlfriend_run/data/enemy_kind.dart';
import 'package:macaron_girlfriend_run/data/game_models.dart';
import 'package:macaron_girlfriend_run/data/save_service.dart';
import 'package:macaron_girlfriend_run/data/synth_wav.dart';
import 'package:macaron_girlfriend_run/game/entities/entities.dart';
import 'package:macaron_girlfriend_run/game/macaron_game.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<MacaronGame> _boot(WidgetTester tester, {int level = 0}) async {
  final game = MacaronGame(
    worldIndex: 0,
    levelIndex: level,
    role: PlayerRole.girlfriend,
  );
  await tester.pumpWidget(GameWidget(game: game));
  await tester.pump(const Duration(milliseconds: 100));
  game.pauseEngine();
  return game;
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

  testWidgets('every normal level hides a gum, superman and plane pickup', (
    tester,
  ) async {
    final game = await _boot(tester);
    final kinds = game.bonusPickups.map((p) => p.kind).toSet();
    expect(kinds, BonusKind.values.toSet());
  });

  testWidgets('holding the AK-47 pulls far coins in (free shopping)', (
    tester,
  ) async {
    final game = await _boot(tester);
    final center = Vector2(
      game.player.position.x,
      game.player.position.y - game.player.size.y * 0.5,
    );
    final far = MacaronCoin(position: center + Vector2(380, 0));
    game.coins
      ..clear()
      ..add(far);
    final start = far.position.clone();
    game.attractCoinsForTest(0.1);
    expect(far.position, start, reason: 'no gun, no pull that far');
    game.gunTimer = 5;
    game.attractCoinsForTest(0.1);
    expect(far.position.x, lessThan(start.x));
  });

  testWidgets('superman mode beams the nearest monster ahead', (tester) async {
    final game = await _boot(tester);
    final enemy = game.enemies.first;
    enemy.position = game.player.position + Vector2(160, 0);
    final before = game.enemies.length;
    game.superTimer = 5;
    game.update(0.02);
    expect(game.enemies.length, before - 1);
    expect(game.enemies.contains(enemy), isFalse);
  });

  testWidgets('the Li car drives itself into monsters ahead', (tester) async {
    final game = await _boot(tester);
    final p = game.player.position;
    final enemy = SoftEnemy(
      position: Vector2(p.x + 170, p.y),
      leftBound: p.x + 100,
      rightBound: p.x + 260,
      difficulty: 1,
      speed: 0,
      kind: EnemyKind.walker,
    );
    game.enemies
      ..clear()
      ..add(enemy);
    game.world.add(enemy);
    game.vehicleTimer = 8;
    for (var i = 0; i < 120 && game.enemies.contains(enemy); i++) {
      game.update(1 / 60);
    }
    expect(game.enemies.contains(enemy), isFalse);
  });

  test('march, waltz and the outro are valid, distinct wav files', () {
    final march = SynthWav.marchLoop();
    final gum = SynthWav.gumLoop();
    final out = SynthWav.mambaOut();
    for (final wav in [march, gum, out]) {
      expect(String.fromCharCodes(wav.sublist(0, 4)), 'RIFF');
    }
    expect(march.length, isNot(gum.length));
    expect(out.length, greaterThan(100000));
  });
}
