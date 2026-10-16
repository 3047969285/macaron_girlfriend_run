import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:macaron_girlfriend_run/data/game_models.dart';
import 'package:macaron_girlfriend_run/game/render/terrain_renderer.dart';

void main() {
  test(
    'nine platform materials survive picture caching and preserve bounds',
    () async {
      const tiles = [
        TerrainTile(rect: Rect.fromLTWH(24, 32, 48, 48), isGround: false),
        TerrainTile(rect: Rect.fromLTWH(72, 32, 48, 48), isGround: false),
        TerrainTile(rect: Rect.fromLTWH(120, 32, 48, 48), isGround: false),
      ];
      Future<List<int>> pixelsOf(TerrainRenderer renderer) async {
        final recorder = ui.PictureRecorder();
        renderer.render(Canvas(recorder));
        final picture = recorder.endRecording();
        final image = await picture.toImage(200, 112);
        final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        final pixels = List<int>.of(
          data!.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        );
        image.dispose();
        picture.dispose();
        return pixels;
      }

      final signatures = <String>{};
      for (final palette in WorldCatalog.palettes) {
        final renderer = TerrainRenderer(
          solids: tiles,
          palette: palette,
          mapWidth: 200,
          groundY: 640,
          sceneSeed: 7,
        );
        final direct = await pixelsOf(renderer);
        await renderer.onLoad();
        expect(await pixelsOf(renderer), equals(direct), reason: palette.name);
        signatures.add(base64Encode(direct));
        expect(tiles.first.rect, const Rect.fromLTWH(24, 32, 48, 48));
        expect(tiles.last.rect, const Rect.fromLTWH(120, 32, 48, 48));
        renderer.onRemove();
      }
      expect(signatures, hasLength(WorldCatalog.palettes.length));
    },
  );

  test('each world palette paints terrain without throwing', () async {
    expect(WorldCatalog.palettes, hasLength(9));
    for (final palette in WorldCatalog.palettes) {
      final renderer = TerrainRenderer(
        solids: const [
          TerrainTile(rect: Rect.fromLTWH(0, 600, 48, 48), isGround: true),
          TerrainTile(rect: Rect.fromLTWH(96, 480, 48, 48), isGround: false),
        ],
        palette: palette,
        mapWidth: 960,
        groundY: 648,
        sceneSeed: 7,
      );
      await renderer.onLoad();
      final recorder = ui.PictureRecorder();
      renderer.render(Canvas(recorder));
      recorder.endRecording().dispose();
      renderer.onRemove();
    }
  });
}
