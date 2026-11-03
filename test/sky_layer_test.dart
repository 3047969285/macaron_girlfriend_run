import 'package:flame/game.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:macaron_girlfriend_run/data/game_models.dart';
import 'package:macaron_girlfriend_run/data/level_catalog.dart';
import 'package:macaron_girlfriend_run/data/save_service.dart';
import 'package:macaron_girlfriend_run/game/macaron_game.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 起跳弹簧：天空层之下、地面之上的那颗 'S'（最靠下的一颗）。
(int, int)? _launchSpring(LevelData level) {
  for (var y = level.height - 4; y >= 0; y--) {
    for (var x = 0; x < level.width; x++) {
      if (level.tileAt(x, y) == 'S' && y >= LevelCatalog.skyRows) {
        return (x, y);
      }
    }
  }
  return null;
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

  test('most normal levels grow a sky layer; boss levels stay flat', () {
    var tall = 0;
    for (var w = 0; w < GameConstants.worldCount; w++) {
      for (var l = 0; l < GameConstants.levelsPerWorld - 1; l++) {
        if (LevelCatalog.load(w, l).height > 14) {
          tall++;
        }
      }
      expect(
        LevelCatalog.load(w, GameConstants.levelsPerWorld - 1).height,
        14,
        reason: 'boss level of world $w',
      );
    }
    // 要有一块上方完全空出来的实心地面，不是每一关都放得下。
    expect(tall, greaterThan(GameConstants.worldCount * 3));
  });

  testWidgets('the spring route lifts the player onto the sky island', (
    tester,
  ) async {
    // 找一关有天空层的。
    LevelData? level;
    var world = 0;
    var index = 0;
    for (var w = 0; w < GameConstants.worldCount && level == null; w++) {
      for (var l = 0; l < GameConstants.levelsPerWorld - 1; l++) {
        final candidate = LevelCatalog.load(w, l);
        if (candidate.height > 14) {
          level = candidate;
          world = w;
          index = l;
          break;
        }
      }
    }
    expect(level, isNotNull);
    final spring = _launchSpring(level!)!;
    final game = MacaronGame(
      worldIndex: world,
      levelIndex: index,
      role: PlayerRole.girlfriend,
    );
    await tester.pumpWidget(GameWidget(game: game));
    await tester.pump(const Duration(milliseconds: 100));
    game.pauseEngine();
    game.update(1 / 60);

    const tile = GameConstants.tileSize;
    // 站在起跳弹簧正上方一点，落下去就会触发。
    game.player.position.setValues(
      spring.$1 * tile + tile / 2,
      spring.$2 * tile - 6,
    );
    game.player.velocity.setZero();
    var minY = game.player.position.y;
    for (var i = 0; i < 60 * 14; i++) {
      // 上升时往右带一点，落到下一块平台上。
      game.rightPressed =
          game.player.velocity.y < -50 &&
          game.player.position.x < (spring.$1 + 18) * tile;
      game.jumpPressedEdge = false;
      game.update(1 / 60);
      if (game.player.position.y < minY) {
        minY = game.player.position.y;
      }
    }
    // 岛在天空层里（前 skyRows 行以内），角色至少要升到那一带。
    expect(
      minY,
      lessThan(LevelCatalog.skyRows * tile),
      reason: 'the player should rise into the sky layer',
    );
  });
}
