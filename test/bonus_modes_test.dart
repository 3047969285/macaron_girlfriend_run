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

  testWidgets('the plane flies freely in all four directions', (tester) async {
    final game = await _boot(tester);
    game.update(1 / 60);
    final plane = game.bonusPickups.firstWhere(
      (p) => p.kind == BonusKind.plane,
    );
    game.player.position.setFrom(plane.position + Vector2(0, 40));
    game.update(1 / 60);
    expect(game.planeTimer, greaterThan(0));
    game.rightPressed = false;
    game.leftPressed = false;

    Future<(double, double)> fly({
      bool right = false,
      bool left = false,
      bool up = false,
      bool down = false,
    }) async {
      game.rightPressed = right;
      game.leftPressed = left;
      game.upPressed = up;
      game.downPressed = down;
      final start = game.player.position.clone();
      for (var i = 0; i < 40; i++) {
        game.update(1 / 60);
      }
      game.rightPressed = game.leftPressed = false;
      game.upPressed = game.downPressed = false;
      return (
        game.player.position.x - start.x,
        game.player.position.y - start.y,
      );
    }

    final hover = await fly();
    expect(hover.$1.abs(), lessThan(8), reason: 'no input hovers');
    expect(hover.$2.abs(), lessThan(40));

    // 先放到一块开阔的空地（天空层以下、地面以上），再依次试四个方向。
    game.player.position.setFrom(plane.position + Vector2(0, -20));
    final u = await fly(up: true);
    expect(u.$2, lessThan(-20), reason: 'up climbs');
    final d = await fly(down: true);
    expect(d.$2, greaterThan(20), reason: 'down descends');
    final r = await fly(right: true);
    expect(r.$1, greaterThan(100), reason: 'right flies right');
    final l = await fly(left: true);
    expect(l.$1, lessThan(-100), reason: 'left flies left');
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
