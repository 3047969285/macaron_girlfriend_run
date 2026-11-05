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
