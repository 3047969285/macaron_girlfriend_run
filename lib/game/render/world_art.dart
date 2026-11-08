import 'package:macaron_girlfriend_run/data/song_profile.dart';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';

/// 六个世界共用的图集，各自加载后即可用于绘制。
class WorldArt {
  WorldArt._();

  static ui.Image? _atlas;
  static ui.Image? _backgrounds;
  static ui.Image? _enemies;
  static Future<void>? _loading;
  static Future<void>? _terrainLoading;
  static Future<void>? get terrainLoading => _terrainLoading;
  static bool get ready => _atlas != null;
  static bool get backgroundsReady => _backgrounds != null;
  static bool get enemiesReady => _enemies != null;
  // 图集是像素画，放大到关卡尺寸时用最近邻，保持硬边；双线性会把背景糊成一片。
  static final _paint = ui.Paint()..filterQuality = ui.FilterQuality.none;

  static Future<void> preload() => _loading ??= _load();

  static Future<void> _load() async {
    if (_atlas == null) {
      _terrainLoading = _loadImage('world-atlas').then<void>((image) {
        _atlas = image;
      });
      await _terrainLoading;
    }
    _backgrounds ??= await _loadImage('background-atlas');
    _enemies ??= await _loadImage('enemy-atlas');
    if (_atlas == null || _backgrounds == null || _enemies == null) {
      _loading = null;
    }
  }

  static Future<ui.Image?> _loadImage(String name) async {
    try {
      final data = await rootBundle.load('assets/worlds/$name.webp');
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      try {
        return (await codec.getNextFrame()).image;
      } finally {
        codec.dispose();
      }
    } catch (_) {
      return null;
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
      _paint,
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
      _paint,
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
      _paint,
    );
  }
}
