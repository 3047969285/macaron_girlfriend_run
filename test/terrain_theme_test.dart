import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:macaron_girlfriend_run/data/game_models.dart';
import 'package:macaron_girlfriend_run/game/render/terrain_renderer.dart';

void main() {
  test('each world palette paints terrain without throwing', () async {
    expect(WorldCatalog.palettes, hasLength(9));
    for (final palette in WorldCatalog.palettes) {
      final renderer = TerrainRenderer(
        solids: const [
          TerrainTile(
            rect: Rect.fromLTWH(0, 600, 48, 48),
            isGround: true,
          ),
          TerrainTile(
            rect: Rect.fromLTWH(96, 480, 48, 48),
            isGround: false,
          ),
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
