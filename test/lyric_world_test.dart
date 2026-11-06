import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:macaron_girlfriend_run/data/game_models.dart';
import 'package:macaron_girlfriend_run/data/level_catalog.dart';
import 'package:macaron_girlfriend_run/data/level_scenes.dart';
import 'package:macaron_girlfriend_run/data/lyric_world.dart';
import 'package:macaron_girlfriend_run/data/song_profile.dart';
import 'package:macaron_girlfriend_run/game/render/terrain_renderer.dart';

void main() {
  test('each song has three distinct playable chapter layouts', () {
    for (var song = 0; song < SongProfile.songs.length; song++) {
      final world = SongProfile.worldSongs.indexOf(song);
      final shapes = <String>{};
      for (final level in [0, 4, 8]) {
        final map = LevelCatalog.load(world, level);
        final scene = LevelCatalog.scenesOf(
          world,
          level,
        ).firstWhere((item) => item.lyricRoute != null);
        final bricks =
            scene.cells.entries.where((item) => '=?'.contains(item.value)).map((
              item,
            ) {
              final dx = item.key.$1 - scene.x;
              return (
                scene.mirrored ? scene.width - 1 - dx : dx,
                map.height - 3 - item.key.$2,
              );
            }).toList()..sort(
              (a, b) =>
                  a.$1 != b.$1 ? a.$1.compareTo(b.$1) : a.$2.compareTo(b.$2),
            );
        shapes.add(bricks.toString());
      }
      expect(shapes, hasLength(3), reason: SongProfile.songs[song].title);
    }
  });

  test('chapter story landmarks render differently for each song', () async {
    for (var song = 0; song < SongProfile.songs.length; song++) {
      final world = SongProfile.worldSongs.indexOf(song);
      final scene = LevelCatalog.scenesOf(
        world,
        0,
      ).firstWhere((item) => item.lyricRoute != null);
      final signatures = <String>{};
      for (final chapter in LyricWorld.chapters[song]) {
        final renderer = TerrainRenderer(
          solids: const [],
          palette: WorldCatalog.paletteOf(world),
          mapWidth: 2000,
          groundY: 400,
          sceneSeed: 1,
          lyricChapter: chapter,
          scenes: [scene],
        );
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder)
          ..translate(
            -(scene.x + scene.width / 2) * GameConstants.tileSize + 200,
            0,
          );
        renderer.render(canvas);
        final picture = recorder.endRecording();
        final image = await picture.toImage(400, 400);
        final bytes = await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        );
        signatures.add(base64Encode(bytes!.buffer.asUint8List()));
        image.dispose();
        picture.dispose();
      }
      expect(signatures, hasLength(3), reason: SongProfile.songs[song].title);
    }
  });

  test(
    'every song has three narrative chapters and matching scene choices',
    () {
      expect(LyricWorld.chapters.length, SongProfile.songs.length);
      for (var world = 0; world < 9; world++) {
        final chapters = [
          for (final level in [0, 4, 8]) LyricWorld.chapterFor(world, level),
        ];
        expect(chapters.map((c) => c.name).toSet(), hasLength(3));
        final preferred =
            LyricWorld.preferredSceneKinds[SongProfile.songIndexOf(world)];
        for (var phase = 0; phase < 3; phase++) {
          expect(
            LyricWorld.sceneBias(world, [0, 4, 8][phase], preferred[phase]),
            greaterThan(0),
          );
          expect(LevelCatalog.scenesOf(world, [0, 4, 8][phase]), isNotEmpty);
        }
      }
      var matchingPlans = 0;
      for (var world = 0; world < 9; world++) {
        for (var level = 0; level < 11; level++) {
          final kind =
              SceneKind.values[LyricWorld.preferredScene(world, level)];
          if (LevelScenes.planKinds(world, level).contains(kind)) {
            matchingPlans++;
          }
        }
      }
      expect(matchingPlans, greaterThanOrEqualTo(85));
    },
  );

  test(
    'landmarks create distinct images at playable scene positions',
    () async {
      final signatures = <String>{};
      final scenes = LevelCatalog.scenesOf(0, 0);
      final first = scenes.first;
      for (final landmark in LyricLandmark.values) {
        final renderer = TerrainRenderer(
          solids: const [],
          palette: WorldCatalog.paletteOf(0),
          mapWidth: 2000,
          groundY: 400,
          sceneSeed: 1,
          lyricChapter: LyricChapter('test', landmark),
          scenes: [first],
        );
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder)
          ..translate(
            -(first.x + first.width / 2) * GameConstants.tileSize + 120,
            0,
          );
        renderer.render(canvas);
        final picture = recorder.endRecording();
        final image = await picture.toImage(240, 400);
        final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        signatures.add(base64Encode(data!.buffer.asUint8List()));
        image.dispose();
        picture.dispose();
      }
      expect(signatures, hasLength(LyricLandmark.values.length));
    },
  );
}
