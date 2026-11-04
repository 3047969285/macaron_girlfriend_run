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
    // 路线上的弹簧（从下往上依次是起跳、第一块、第二块平台上的）。
    final springs = <(int, int)>[
      for (var y = level.height - 4; y >= 0; y--)
        for (var x = spring.$1; x <= spring.$1 + 8; x++)
          if (level.tileAt(x, y) == 'S' && y <= spring.$2) (x, y),
    ];
    for (var i = 0; i < 60 * 20; i++) {
      final feet = game.player.position;
      // 下一颗要踩的弹簧：比脚下高的里面最低的一颗。
      (int, int)? next;
      for (final sp in springs) {
        if (sp.$2 * tile < feet.y - 6 && (next == null || sp.$2 > next.$2)) {
          next = sp;
        }
      }
      final targetX = next == null ? feet.x : next.$1 * tile + tile / 2;
      final rising = game.player.velocity.y < -50;
      // 上升时往目标方向带一点；站着时走到弹簧上面。
      game.rightPressed =
          targetX > feet.x + 6 && (rising || game.player.onGround);
      game.leftPressed =
          targetX < feet.x - 6 && (rising || game.player.onGround);
      game.jumpPressedEdge = false;
      game.update(1 / 60);
      if (game.player.position.y < minY) {
        minY = game.player.position.y;
      }
    } // 岛在天空层里（前 skyRows 行以内），角色至少要升到那一带。
    expect(
      minY,
      lessThan(LevelCatalog.skyRows * tile),
      reason: 'the player should rise into the sky layer',
    );
  });
}
