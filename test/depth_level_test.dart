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

  testWidgets('walking off each platform edge steps down to the flag', (
    tester,
  ) async {
    LevelResult? result;
    final game = MacaronGame(
      worldIndex: 0,
      levelIndex: GameConstants.depthLevelIndex,
      role: PlayerRole.girlfriend,
      onWin: (r) => result = r,
    );
    await tester.pumpWidget(GameWidget(game: game));
    await tester.pump(const Duration(milliseconds: 100));
    game.pauseEngine();
    game.update(1 / 60);

    const tile = GameConstants.tileSize;
    var dir = 1;
    var startRow = game.player.position.y / tile;
    for (var i = 0; i < 60 * 120 && result == null; i++) {
      final row = game.player.position.y / tile;
      if (game.player.onGround) {
        if (row >= LevelCatalog.depthHeight - 3.5) {
          dir = 1; // 到底了：向右走向旗杆
        } else {
          // 偶数层向右走，奇数层向左走。
          final layer = ((row - 6) / 5).round();
          dir = layer.isEven ? 1 : -1;
        }
      }
      // 地面上的怪：靠近就跳过去。
      var jump = false;
      for (final e in game.enemies) {
        final dx = (e.position.x - game.player.position.x) * dir;
        if (game.player.onGround &&
            dx > 20 &&
            dx < 120 &&
            (e.position.y - game.player.position.y).abs() < 40) {
          jump = true;
        }
      }
      game.setJumpHeld(jump);
      game.jumpPressedEdge = jump;
      game.rightPressed = dir > 0;
      game.leftPressed = dir < 0;
      game.update(1 / 60);
      startRow = row;
    }
    expect(startRow, greaterThan(LevelCatalog.depthHeight - 5));
    expect(result, isNotNull, reason: 'reached the flag by only walking');
    expect(result!.cleared, isTrue);
  });
}
