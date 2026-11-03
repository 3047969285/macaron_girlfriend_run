import 'package:flame/game.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:macaron_girlfriend_run/data/game_models.dart';
import 'package:macaron_girlfriend_run/data/level_catalog.dart';
import 'package:macaron_girlfriend_run/data/save_service.dart';
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

  test(
    'every world has a tall descent stage: start high, goal at the bottom',
    () {
      for (var w = 0; w < GameConstants.worldCount; w++) {
        final level = LevelCatalog.load(w, GameConstants.depthLevelIndex);
        expect(level.levelIndex, GameConstants.depthLevelIndex);
        expect(level.height, greaterThan(40), reason: 'world $w');
        var startY = -1;
        var goalY = -1;
        for (var y = 0; y < level.height; y++) {
          if (level.rows[y].contains('P')) startY = y;
          if (level.rows[y].contains('F')) goalY = y;
        }
        expect(startY, lessThan(10), reason: 'start is near the top, world $w');
        expect(
          goalY,
          level.height - 3,
          reason: 'goal sits on the floor, world $w',
        );
        expect(
          level.rows.join().split('K').length - 1,
          greaterThanOrEqualTo(2),
          reason: 'checkpoints on the way down, world $w',
        );
      }
    },
  );

  test('descent layouts differ between the song worlds', () {
    final shapes = <String>{
      for (var w = 0; w < GameConstants.worldCount; w++)
        LevelCatalog.load(w, GameConstants.depthLevelIndex).rows.join('\n'),
    };
    expect(shapes.length, GameConstants.worldCount);
  });

  test('each layer lands on the next one when walked off its end', () {
    for (var w = 0; w < GameConstants.worldCount; w++) {
      final layers = LevelCatalog.depthLayers(w);
      for (var k = 0; k + 1 < layers.length; k++) {
        final (x0, len, _, dir) = layers[k];
        final (nx0, nlen, _, _) = layers[k + 1];
        final beyond = dir > 0 ? x0 + len + 1 : x0 - 2;
        expect(
          beyond >= nx0 && beyond < nx0 + nlen,
          isTrue,
          reason:
              'world $w layer $k walks off at $beyond but next spans '
              '$nx0..${nx0 + nlen - 1}',
        );
        expect(x0, greaterThan(1), reason: 'world $w layer $k inside walls');
        expect(x0 + len, lessThan(LevelCatalog.depthWidth - 1));
      }
    }
  });

  for (var world = 0; world < GameConstants.worldCount; world++) {
    testWidgets('world $world: walking off the ledges reaches the flag', (
      tester,
    ) async {
      LevelResult? result;
      final game = MacaronGame(
        worldIndex: world,
        levelIndex: GameConstants.depthLevelIndex,
        role: PlayerRole.girlfriend,
        onWin: (r) => result = r,
      );
      await tester.pumpWidget(GameWidget(game: game));
      await tester.pump(const Duration(milliseconds: 100));
      game.pauseEngine();
      game.update(1 / 60);

      final layers = LevelCatalog.depthLayers(world);
      const tile = GameConstants.tileSize;
      var dir = 1;
      var lastRow = 0.0;
      for (var i = 0; i < 60 * 150 && result == null; i++) {
        final row = game.player.position.y / tile;
        final col = game.player.position.x / tile;
        var jump = false;
        if (game.player.onGround) {
          if (row >= LevelCatalog.depthHeight - 3.5) {
            dir = 1; // 到底了：向右走向旗杆
          } else {
            final k =
                (((row - LevelCatalog.depthFirstRow) / LevelCatalog.depthRowGap)
                        .round())
                    .clamp(0, layers.length - 1);
            final (x0, len, _, d) = layers[k];
            dir = d;
            // 平台中间的缺口：跳过去。
            final ahead = (col + dir * 1.4).floor();
            if (ahead >= x0 &&
                ahead < x0 + len &&
                game.level.tileAt(ahead, row.round()) != '=') {
              jump = true;
            }
          }
          // 地面上的怪：靠近就跳过去。
          for (final e in game.enemies) {
            final dx = (e.position.x - game.player.position.x) * dir;
            if (dx > 20 &&
                dx < 120 &&
                (e.position.y - game.player.position.y).abs() < 40) {
              jump = true;
            }
          }
        }
        game.setJumpHeld(jump);
        game.jumpPressedEdge = jump;
        game.rightPressed = dir > 0;
        game.leftPressed = dir < 0;
        game.update(1 / 60);
        lastRow = row;
      }
      expect(
        lastRow,
        greaterThan(LevelCatalog.depthHeight - 5),
        reason: 'world $world pilot reached the floor',
      );
      expect(result, isNotNull, reason: 'world $world reached the flag');
      expect(result!.cleared, isTrue);
    });
  }
}
