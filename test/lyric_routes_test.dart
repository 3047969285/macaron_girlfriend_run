import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:macaron_girlfriend_run/data/game_models.dart';
import 'package:macaron_girlfriend_run/data/level_catalog.dart';
import 'package:macaron_girlfriend_run/data/save_service.dart';
import 'package:macaron_girlfriend_run/data/song_profile.dart';
import 'package:macaron_girlfriend_run/game/macaron_game.dart';

int landingOffset(int song, int phase) => switch (song) {
  0 => 16,
  1 || 3 => 17,
  2 || 4 => 9 + phase,
  _ => 18 + phase,
};

void main() {
  testWidgets('a jump from the main lyric route can reach its new landing', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'sound_on': false,
      'music_on': false,
      'haptic_on': false,
    });
    await SaveService.instance.init();
    for (var world = 0; world < 9; world++) {
      for (var level = 4; level < 11; level++) {
        final game = MacaronGame(
          worldIndex: world,
          levelIndex: level,
          role: PlayerRole.girlfriend,
        );
        await tester.pumpWidget(GameWidget(game: game));
        await tester.pump(const Duration(milliseconds: 100));
        game.pauseEngine();
        final scene = LevelCatalog.scenesOf(
          world,
          level,
        ).firstWhere((s) => s.lyricRoute != null);
        final song = SongProfile.songIndexOf(world);
        final phase = level * 3 ~/ 11;
        final startDx = switch (song) {
          0 => 11 + phase,
          1 || 3 => 13 + phase,
          2 || 4 => 6 + phase,
          _ => 15 + phase,
        };
        final startHeight = switch (song) {
          0 => 7,
          1 => 9,
          3 => 8,
          _ => 10,
        };
        final targetDx = landingOffset(song, phase);
        int col(int dx) =>
            scene.x + (scene.mirrored ? scene.width - 1 - dx : dx);
        final startX = (col(startDx) + 0.5) * GameConstants.tileSize;
        final targetX = (col(targetDx) + 0.5) * GameConstants.tileSize;
        final ground = game.level.height - 3;
        final targetY = (ground - 7) * GameConstants.tileSize;
        game.player
          ..position.setValues(
            startX,
            (ground - startHeight) * GameConstants.tileSize,
          )
          ..velocity.setZero()
          ..onGround = true;
        game.runPressed = true;
        game.rightPressed = targetX > startX;
        game.leftPressed = targetX < startX;
        game.setJumpHeld(true);
        var landed = false;
        for (var i = 0; i < 150; i++) {
          if ((game.player.position.x - targetX).abs() < 18) {
            game.rightPressed = false;
            game.leftPressed = false;
          }
          if (i == 35) game.setJumpHeld(false);
          game.update(1 / 60);
          if (game.player.onGround &&
              (game.player.position.y - targetY).abs() < 1 &&
              (game.player.position.x - targetX).abs() <
                  GameConstants.tileSize) {
            landed = true;
            break;
          }
        }
        expect(
          landed,
          isTrue,
          reason:
              'world $world level $level start=$startX target=$targetX position=${game.player.position}',
        );
        await tester.pumpWidget(const SizedBox.shrink());
      }
    }
  });
  testWidgets('new lyric landings support the live player', (tester) async {
    SharedPreferences.setMockInitialValues({
      'sound_on': false,
      'music_on': false,
      'haptic_on': false,
    });
    await SaveService.instance.init();
    var checkedRewards = 0;
    for (var world = 0; world < 9; world++) {
      for (var level = 4; level < 11; level++) {
        final game = MacaronGame(
          worldIndex: world,
          levelIndex: level,
          role: PlayerRole.girlfriend,
        );
        await tester.pumpWidget(GameWidget(game: game));
        await tester.pump(const Duration(milliseconds: 100));
        expect(game.levelReady, isTrue);
        game.pauseEngine();
        final scene = LevelCatalog.scenesOf(
          world,
          level,
        ).firstWhere((s) => s.lyricRoute != null);
        final offset = landingOffset(
          SongProfile.songIndexOf(world),
          level * 3 ~/ 11,
        );
        final col =
            scene.x + (scene.mirrored ? scene.width - 1 - offset : offset);
        final top = (game.level.height - 3 - 7) * GameConstants.tileSize;
        final rewardRow = game.level.height - 3 - 8;
        final rewards = game.coins
            .where(
              (coin) =>
                  (coin.position.x - (col + 0.5) * GameConstants.tileSize)
                          .abs() <
                      1 &&
                  (coin.position.y - (rewardRow + 0.5) * GameConstants.tileSize)
                          .abs() <
                      1,
            )
            .toList();
        game.player
          ..position.setValues((col + 0.5) * GameConstants.tileSize, top - 12)
          ..velocity.setValues(0, 200)
          ..onGround = false;
        var landed = false;
        for (var i = 0; i < 10; i++) {
          game.update(1 / 60);
          if (game.player.onGround &&
              (game.player.position.y - top).abs() < 1) {
            landed = true;
          }
        }
        expect(
          landed,
          isTrue,
          reason:
              'world $world level $level landing at ${game.player.position}, expected y=$top',
        );
        if (scene.cells[(col, rewardRow)] == 'C') {
          expect(
            rewards,
            hasLength(1),
            reason: 'world $world level $level reward created',
          );
          expect(
            rewards.single.collected,
            isTrue,
            reason: 'world $world level $level reward collected',
          );
          checkedRewards++;
        }
        await tester.pumpWidget(const SizedBox.shrink());
      }
    }
    expect(checkedRewards, greaterThan(0));
  });
  test('later lyric routes retain their optional lower landing', () {
    for (var world = 0; world < 9; world++) {
      for (var level = 4; level < 11; level++) {
        final song = SongProfile.songIndexOf(world);
        final offset = landingOffset(song, level * 3 ~/ 11);
        final ground = LevelCatalog.load(world, level).height - 3;
        final routes = LevelCatalog.scenesOf(
          world,
          level,
        ).where((scene) => scene.lyricRoute != null);
        expect(routes, isNotEmpty, reason: 'world $world level $level');
        expect(
          routes.any((scene) {
            int col(int dx) =>
                scene.x + (scene.mirrored ? scene.width - 1 - dx : dx);
            return scene.cells[(col(offset), ground - 7)] == '=' &&
                scene.cells[(col(offset + 1), ground - 7)] == '=';
          }),
          isTrue,
          reason: 'missing landing in world $world level $level',
        );
      }
    }
  });
  test('each song has playable lyric routes in all three chapters', () {
    var levelsWithLyricRoutes = 0;
    for (var world = 0; world < 9; world++) {
      final signatures = <Set<String>>[];
      for (var chapter = 0; chapter < 3; chapter++) {
        final found = <String>{};
        for (var level = 0; level < 11; level++) {
          if (level * 3 ~/ 11 != chapter) continue;
          final base = LevelCatalog.loadBase(world, level);
          final full = LevelCatalog.load(world, level);
          final ground = base.height - 3;
          expect(full.rows[ground], base.rows[ground]);
          expect(full.rows[ground + 1], base.rows[ground + 1]);
          expect(full.rows[ground + 2], base.rows[ground + 2]);
          final scenes = LevelCatalog.scenesOf(world, level);
          if (scenes.any((scene) => scene.lyricRoute != null)) {
            levelsWithLyricRoutes++;
          }
          for (final scene in scenes) {
            if (scene.lyricRoute == null) continue;
            final solids = scene.cells.entries
                .where((e) => '=?'.contains(e.value))
                .toList();
            expect(solids.length, greaterThanOrEqualTo(7));
            for (final entry in solids) {
              expect(full.rows[entry.key.$2][entry.key.$1], entry.value);
            }
            final origin = solids
                .map((e) => e.key.$1)
                .reduce((a, b) => a < b ? a : b);
            final shape =
                solids
                    .map((e) => '${e.key.$1 - origin}:${ground - e.key.$2}')
                    .toList()
                  ..sort();
            found.add(shape.join(','));
          }
        }
        expect(found, isNotEmpty, reason: 'world $world chapter $chapter');
        signatures.add(found);
      }
      expect(
        signatures.first.difference(signatures.last),
        isNotEmpty,
        reason:
            'world $world should change its playable route between chapters',
      );
    }
    expect(levelsWithLyricRoutes, 99);
  });
}
