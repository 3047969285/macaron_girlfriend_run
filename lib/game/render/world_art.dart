import 'package:macaron_girlfriend_run/data/song_profile.dart';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';

/// 六个世界共用的图集，启动时解码一次，绘制时不再分配图片。
class WorldArt {
  WorldArt._();

  static ui.Image? _atlas;
  static ui.Image? _backgrounds;
  static ui.Image? _enemies;
  static bool get ready => _atlas != null;

  static Future<void> preload() async {
    if (_atlas != null) return;
    final data = await rootBundle.load('assets/worlds/world-atlas.png');
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    try {
      _atlas = (await codec.getNextFrame()).image;
    } finally {
      codec.dispose();
    }
    final backgroundData = await rootBundle.load(
      'assets/worlds/background-atlas.png',
    );
    final backgroundCodec = await ui.instantiateImageCodec(
      backgroundData.buffer.asUint8List(),
    );
    try {
      _backgrounds = (await backgroundCodec.getNextFrame()).image;
    } finally {
      backgroundCodec.dispose();
    }
    final enemyData = await rootBundle.load('assets/worlds/enemy-atlas.png');
    final enemyCodec = await ui.instantiateImageCodec(
      enemyData.buffer.asUint8List(),
    );
    try {
      _enemies = (await enemyCodec.getNextFrame()).image;
    } finally {
      enemyCodec.dispose();
    }
  }

  static void enemy(ui.Canvas canvas, int world, int column, ui.Rect target) {
    final atlas = _enemies;
    if (atlas == null) return;
    final width = atlas.width / 4;
    final height = atlas.height / 6;
    canvas.drawImageRect(
      atlas,
      ui.Rect.fromLTWH(
        column * width,
        SongProfile.songIndexOf(world) * height,
        width,
        height,
      ),
      target,
      ui.Paint()..filterQuality = ui.FilterQuality.none,
    );
  }

  static void background(
    ui.Canvas canvas,
    int world,
    int layer,
    ui.Rect target,
  ) {
    final atlas = _backgrounds;
    if (atlas == null) return;
    final width = atlas.width / 3;
    final height = atlas.height / 6;
    canvas.drawImageRect(
      atlas,
      ui.Rect.fromLTWH(
        layer * width,
        SongProfile.songIndexOf(world) * height,
        width,
        height,
      ),
      target,
      ui.Paint()..filterQuality = ui.FilterQuality.none,
    );
  }

  static void draw(ui.Canvas canvas, int world, int column, ui.Rect target) {
    final atlas = _atlas;
    if (atlas == null) return;
    final width = atlas.width / 8;
    final height = atlas.height / 6;
    canvas.drawImageRect(
      atlas,
      ui.Rect.fromLTWH(
        column * width,
        SongProfile.songIndexOf(world) * height,
        width,
        height,
      ).deflate(column < 2 ? width * 0.1 : 0),
      target,
      ui.Paint()..filterQuality = ui.FilterQuality.none,
    );
  }
}
