import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:macaron_girlfriend_run/data/enemy_kind.dart';
import 'package:macaron_girlfriend_run/data/game_models.dart';
import 'package:macaron_girlfriend_run/data/level_catalog.dart';
import 'package:macaron_girlfriend_run/data/save_service.dart';
import 'package:macaron_girlfriend_run/data/song_profile.dart';
import 'package:macaron_girlfriend_run/data/song_world_theme.dart';
import 'package:macaron_girlfriend_run/game/effects/parallax_layer.dart';
import 'package:macaron_girlfriend_run/game/entities/entities.dart';
import 'package:macaron_girlfriend_run/game/macaron_game.dart';
import 'package:macaron_girlfriend_run/game/player/hero_sprites.dart';
import 'package:macaron_girlfriend_run/game/render/terrain_renderer.dart';

Future<String> imageOf(void Function(Canvas) draw) async {
  final recorder = ui.PictureRecorder();
  draw(Canvas(recorder)..translate(100, 120));
  final picture = recorder.endRecording();
  final image = await picture.toImage(240, 180);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  final signature = base64Encode(bytes!.buffer.asUint8List());
  image.dispose();
  picture.dispose();
  return signature;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('all song backdrops decode successfully', () async {
    for (final theme in SongWorldTheme.values) {
      final world = SongProfile.worldSongs.indexOf(theme.index);
      final backdrop = WorldBackdrop(
        palette: WorldCatalog.paletteOf(world),
        mapWidth: 1000,
        sceneSeed: 1,
        songTheme: theme,
      );
      await backdrop.onLoad();
      await backdrop.backgroundLoading;
      expect(backdrop.songBackgroundLoaded, isTrue, reason: theme.name);
      backdrop.onRemove();
    }
  });

  test('song projectiles have bounded, frame-independent flight patterns', () {
    final paths = <String>{};
    for (final theme in SongWorldTheme.values) {
      final slow = EnemyCandyShot(
        position: Vector2.zero(),
        direction: 1,
        speed: 200,
        theme: theme,
      );
      final fast = EnemyCandyShot(
        position: Vector2.zero(),
        direction: 1,
        speed: 200,
        theme: theme,
      );
      final samples = <String>[];
      for (var i = 0; i < 60; i++) {
        slow.update(1 / 60);
        fast.update(1 / 120);
        fast.update(1 / 120);
        expect((slow.position.y - fast.position.y).abs(), lessThan(0.001));
        expect(slow.position.y.abs(), lessThanOrEqualTo(10));
        if (i % 10 == 9) samples.add(slow.position.y.toStringAsFixed(2));
      }
      paths.add(samples.join(','));
      expect(slow.position.x, closeTo(200, 0.001));
      expect(slow.hitbox.height, lessThan(18));
    }
    expect(paths, hasLength(6));
  });

  test(
    'mirror and clock chapters add a reachable upper path inside the tower',
    () {
      for (final world in [2, 4]) {
        final chapters = <int>{};
        for (var level = 0; level < 11; level++) {
          final map = LevelCatalog.load(world, level);
          final ground = map.height - 3;
          final phase = level * 3 ~/ 11;
          for (final scene in LevelCatalog.scenesOf(world, level)) {
            if (scene.lyricRoute == null || !scene.storyExpansion) continue;
            expect(scene.width, lessThanOrEqualTo(14));
            int col(int dx) =>
                scene.x + (scene.mirrored ? scene.width - 1 - dx : dx);
            final start = phase == 0 ? 12 : 7 + phase;
            final height = phase == 0 ? 9 : 7;
            for (var dx = start; dx < start + 2; dx++) {
              expect(map.tileAt(col(dx), ground - height), '=');
              expect(
                map.tileAt(col(dx), ground - height - 1),
                isNot(anyOf('=', '?')),
              );
              expect(
                map.tileAt(col(dx), ground - height - 2),
                isNot(anyOf('=', '?')),
              );
            }
            chapters.add(phase);
          }
        }
        expect(chapters, {0, 1, 2}, reason: 'world $world');
      }
    },
  );

  testWidgets('the player can reach both new tower paths in every chapter', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'sound_on': false,
      'music_on': false,
      'haptic_on': false,
    });
    await SaveService.instance.init();
    for (final world in [2, 4]) {
      for (var phase = 0; phase < 3; phase++) {
        final level = List.generate(11, (i) => i).firstWhere(
          (i) =>
              i * 3 ~/ 11 == phase &&
              LevelCatalog.scenesOf(
                world,
                i,
              ).any((s) => s.lyricRoute != null && s.storyExpansion),
        );
        final map = LevelCatalog.load(world, level);
        final scene = LevelCatalog.scenesOf(
          world,
          level,
        ).firstWhere((s) => s.lyricRoute != null && s.storyExpansion);
        int col(int dx) =>
            scene.x + (scene.mirrored ? scene.width - 1 - dx : dx);
        final startDx = phase == 0 ? 9 : 9 + phase;
        final targetDx = phase == 0 ? 12 : 8 + phase;
        final startHeight = 7;
        final targetHeight = phase == 0 ? 9 : 7;
        final game = MacaronGame(
          worldIndex: world,
          levelIndex: level,
          role: PlayerRole.girlfriend,
        );
        await tester.pumpWidget(GameWidget(game: game));
        await tester.pump(const Duration(milliseconds: 100));
        game.pauseEngine();
        final startX = (col(startDx) + .5) * GameConstants.tileSize;
        final targetX = (col(targetDx) + .5) * GameConstants.tileSize;
        final targetY =
            (map.height - 3 - targetHeight) * GameConstants.tileSize;
        game.player
          ..position.setValues(
            startX,
            (map.height - 3 - startHeight) * GameConstants.tileSize,
          )
          ..velocity.setZero()
          ..onGround = true;
        game.rightPressed = targetX > startX;
        game.leftPressed = targetX < startX;
        if (phase == 0) game.setJumpHeld(true);
        var reached = false;
        for (var i = 0; i < 120; i++) {
          if ((game.player.position.x - targetX).abs() < 8) {
            game.rightPressed = false;
            game.leftPressed = false;
          }
          if (i == 30) game.setJumpHeld(false);
          game.update(1 / 60);
          if (game.player.onGround &&
              (game.player.position.y - targetY).abs() < 1 &&
              (game.player.position.x - targetX).abs() <
                  GameConstants.tileSize / 2) {
            reached = true;
            break;
          }
        }
        expect(reached, isTrue, reason: 'world $world chapter $phase');
        await tester.pumpWidget(const SizedBox.shrink());
      }
    }
  });

  test('mounted rider images are available', () async {
    await HeroSprites.preload();
    expect(HeroSprites.horseIdle, isNotNull);
    expect(HeroSprites.horseRun, isNotNull);
  });

  test(
    'expanded routes use real platforms for the four compatible song layouts',
    () {
      for (final song in [0, 1, 3, 5]) {
        final world = SongProfile.worldSongs.indexOf(song);
        var count = 0;
        for (var level = 0; level < GameConstants.levelsPerWorld; level++) {
          final map = LevelCatalog.load(world, level);
          for (final scene in LevelCatalog.scenesOf(world, level)) {
            if (!scene.storyExpansion) continue;
            count++;
            expect(
              scene.cells.entries.every(
                (entry) =>
                    map.tileAt(entry.key.$1, entry.key.$2) == entry.value,
              ),
              isTrue,
            );
          }
        }
        expect(count, greaterThan(0), reason: SongProfile.songs[song].title);
      }
    },
  );

  testWidgets(
    'each real song world uses its own rewards, enemies and scenery',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'sound_on': false,
        'music_on': false,
        'haptic_on': false,
      });
      await SaveService.instance.init();
      for (var song = 0; song < SongWorldTheme.values.length; song++) {
        final world = SongProfile.worldSongs.indexOf(song);
        final game = MacaronGame(
          worldIndex: world,
          levelIndex: 0,
          role: PlayerRole.girlfriend,
        );
        await tester.pumpWidget(GameWidget(game: game));
        await tester.pump(const Duration(milliseconds: 100));
        game.pauseEngine();
        expect(game.songTheme, SongWorldTheme.values[song]);
        expect(game.coins, isNotEmpty);
        expect(
          game.coins.every((coin) => coin.theme == game.songTheme),
          isTrue,
        );
        expect(game.enemies, isNotEmpty);
        expect(
          game.enemies.every((enemy) => enemy.theme == game.songTheme),
          isTrue,
        );
        expect(game.parallax!.theme, game.songTheme);
        final backdrop = WorldBackdrop(
          palette: game.palette,
          mapWidth: 1000,
          sceneSeed: 1,
          songTheme: game.songTheme,
        );
        await tester.runAsync(() async {
          await backdrop.onLoad();
          await backdrop.backgroundLoading;
        });
        expect(
          backdrop.songBackgroundLoaded,
          isTrue,
          reason: game.songTheme.name,
        );
        backdrop.onRemove();
        expect(game.player.hasWhiteHorse, song == 1);
        await tester.pumpWidget(const SizedBox.shrink());
      }
    },
  );

  testWidgets(
    'collecting eight themed items activates the corresponding power',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'sound_on': false,
        'music_on': false,
        'haptic_on': false,
      });
      await SaveService.instance.init();
      for (final theme in SongWorldTheme.values) {
        final world = SongProfile.worldSongs.indexOf(theme.index);
        final game = MacaronGame(
          worldIndex: world,
          levelIndex: 0,
          role: PlayerRole.girlfriend,
        );
        await tester.pumpWidget(GameWidget(game: game));
        await tester.pump(const Duration(milliseconds: 100));
        game.pauseEngine();
        final skill = switch (theme) {
          SongWorldTheme.whiteHorse => HeroSkill.dash,
          SongWorldTheme.reflection => HeroSkill.shield,
          SongWorldTheme.lost => HeroSkill.grapple,
          _ => null,
        };
        if (skill != null) {
          game.activateSkill(skill);
          expect(game.cooldownRatioOf(skill), greaterThan(0));
        }
        game.player.velocity.setZero();
        game.player.invincibleTimer = 0;
        game.timeLeft = 40;
        for (final coin in game.coins.take(8)) {
          coin.position.setFrom(game.player.position + Vector2(0, -30));
        }
        game.update(1 / 60);
        expect(game.songRewardProgress, 0, reason: theme.name);
        expect(game.collected, greaterThanOrEqualTo(8), reason: theme.name);
        if (skill != null) expect(game.cooldownRatioOf(skill), 0);
        if (theme == SongWorldTheme.firstLove) {
          expect(game.player.invincibleTimer, greaterThan(1));
        }
        if (theme == SongWorldTheme.quietLove) {
          expect(game.songMagnetRemaining, greaterThan(3));
        }
        if (theme == SongWorldTheme.dawn) {
          expect(game.timeLeft, greaterThan(41));
        }
        await tester.pumpWidget(const SizedBox.shrink());
      }
    },
  );

  testWidgets(
    'white horse follows controls, jumps and gives way in low passages',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'sound_on': false,
        'music_on': false,
        'haptic_on': false,
      });
      await SaveService.instance.init();
      final game = MacaronGame(
        worldIndex: 1,
        levelIndex: 0,
        role: PlayerRole.girlfriend,
      );
      await tester.pumpWidget(GameWidget(game: game));
      await tester.pump(const Duration(milliseconds: 100));
      game.pauseEngine();
      for (var i = 0; i < 60 && !game.player.onGround; i++) {
        game.update(1 / 60);
      }
      expect(game.player.ridingWhiteHorse, isTrue);
      final x = game.player.position.x;
      game.rightPressed = true;
      for (var i = 0; i < 8; i++) {
        game.update(1 / 60);
      }
      expect(game.player.position.x, greaterThan(x));
      game.setJumpHeld(true);
      game.update(1 / 60);
      expect(game.player.velocity.y, lessThan(0));
      for (var i = 0; i < 100 && !game.player.onGround; i++) {
        game.update(1 / 60);
      }
      game.rightPressed = false;
      game.setJumpHeld(false);
      game.duckPressed = true;
      game.update(1 / 60);
      expect(game.player.ducking, isTrue);
      expect(game.player.ridingWhiteHorse, isFalse);
      game.duckPressed = false;
      game.update(1 / 60);
      expect(game.player.ridingWhiteHorse, isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  test(
    'six song worlds have distinct rewards, monsters, bosses and skylines',
    () async {
      final rewards = <String>{};
      final enemies = <String>{};
      final bosses = <String>{};
      final skylines = <String>{};
      for (final theme in SongWorldTheme.values) {
        final world = SongProfile.worldSongs.indexOf(theme.index);
        rewards.add(
          await imageOf(
            (canvas) => MacaronCoin(
              position: Vector2.zero(),
              theme: theme,
            ).render(canvas),
          ),
        );
        enemies.add(
          await imageOf(
            (canvas) => SoftEnemy(
              position: Vector2.zero(),
              leftBound: 0,
              rightBound: 100,
              difficulty: 1,
              kind: EnemyKind.walker,
              theme: theme,
            ).render(canvas),
          ),
        );
        bosses.add(
          await imageOf(
            (canvas) => MacaronBoss(
              position: Vector2.zero(),
              leftBound: 0,
              rightBound: 100,
              worldIndex: world,
            ).render(canvas),
          ),
        );
        skylines.add(
          await imageOf((canvas) {
            canvas.translate(0, -380);
            ParallaxLayer(
              mapWidth: 300,
              farColor: Colors.grey,
              midColor: Colors.blueGrey,
              theme: theme,
            ).render(canvas);
          }),
        );
      }
      expect(rewards, hasLength(6));
      expect(enemies, hasLength(6));
      expect(bosses, hasLength(6));
      expect(skylines, hasLength(6));
    },
  );
}
