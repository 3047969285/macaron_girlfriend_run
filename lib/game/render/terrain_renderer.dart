import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:macaron_girlfriend_run/theme/macaron_colors.dart';

/// 地形块
class TerrainTile {
  const TerrainTile({required this.rect, required this.isGround});

  final Rect rect;
  final bool isGround;
}

/// 平台跳跃地形与装饰绘制（离屏 Picture 缓存，避免每帧重绘砖块）
class TerrainRenderer extends PositionComponent {
  TerrainRenderer({
    required this.solids,
    required this.palette,
    required this.mapWidth,
    required this.groundY,
  }) : super(priority: 0);

  final List<TerrainTile> solids;
  final WorldPalette palette;
  final double mapWidth;
  final double groundY;

  ui.Picture? _picture;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _rebuildPicture();
  }

  @override
  void onRemove() {
    _picture?.dispose();
    _picture = null;
    super.onRemove();
  }

  void _rebuildPicture() {
    _picture?.dispose();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    for (final tile in solids) {
      if (tile.isGround) {
        _drawGroundBlock(canvas, tile.rect);
      } else {
        _drawPlatformBlock(canvas, tile.rect);
      }
    }
    _drawScenery(canvas);
    _picture = recorder.endRecording();
  }

  @override
  void render(Canvas canvas) {
    final pic = _picture;
    if (pic != null) {
      canvas.drawPicture(pic);
      return;
    }
    for (final tile in solids) {
      if (tile.isGround) {
        _drawGroundBlock(canvas, tile.rect);
      } else {
        _drawPlatformBlock(canvas, tile.rect);
      }
    }
    _drawScenery(canvas);
  }

  void _drawGroundBlock(Canvas canvas, Rect r) {
    final body = Paint()
      ..color = Color.lerp(const Color(0xFFC68642), palette.groundDark, 0.35)!;
    canvas.drawRect(r, body);
    final line = Paint()
      ..color = Color.lerp(const Color(0xFF9A6530), palette.groundDark, 0.4)!
      ..strokeWidth = 1.2;
    for (var y = r.top + 8; y < r.bottom; y += 16) {
      canvas.drawLine(Offset(r.left, y), Offset(r.right, y), line);
    }
    for (var x = r.left + 12; x < r.right; x += 24) {
      canvas.drawLine(Offset(x, r.top), Offset(x, r.bottom), line);
    }
    final grass = Paint()..color = palette.ground;
    canvas.drawRect(Rect.fromLTWH(r.left, r.top, r.width, 10), grass);
    final grassDark = Paint()..color = palette.groundDark;
    for (var i = 0; i < r.width / 12; i++) {
      final gx = r.left + i * 12 + 2;
      canvas.drawPath(
        Path()
          ..moveTo(gx, r.top + 10)
          ..lineTo(gx + 3, r.top - 2)
          ..lineTo(gx + 6, r.top + 10),
        grassDark,
      );
    }
    canvas.drawRect(
      r,
      Paint()
        ..color = palette.groundDark
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  void _drawPlatformBlock(Canvas canvas, Rect r) {
    final fill = Paint()..color = palette.accent.withValues(alpha: 0.92);
    final rrect = RRect.fromRectAndRadius(r, const Radius.circular(6));
    canvas.drawRRect(rrect, fill);
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(r.left + 4, r.top + 4, r.width - 8, 6),
        const Radius.circular(3),
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.35),
    );
  }

  void _drawScenery(Canvas canvas) {
    final bush = Paint()..color = palette.groundDark;
    for (var x = 80.0; x < mapWidth; x += 280) {
      _drawBush(canvas, Offset(x, groundY - 4), bush);
    }
    final pipeColor = Color.lerp(palette.ground, palette.accent, 0.45)!;
    for (var x = 320.0; x < mapWidth; x += 560) {
      _drawMacaronPipe(canvas, Offset(x, groundY), pipeColor);
    }
  }

  void _drawBush(Canvas canvas, Offset base, Paint paint) {
    canvas.drawCircle(Offset(base.dx - 10, base.dy - 8), 12, paint);
    canvas.drawCircle(Offset(base.dx + 8, base.dy - 10), 14, paint);
    canvas.drawCircle(Offset(base.dx + 22, base.dy - 6), 10, paint);
  }

  void _drawMacaronPipe(Canvas canvas, Offset base, Color color) {
    const w = 44.0;
    const h = 64.0;
    final body = Paint()..color = color;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(base.dx, base.dy - h, w, h),
        const Radius.circular(8),
      ),
      body,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(base.dx - 4, base.dy - h - 8, w + 8, 14),
        const Radius.circular(6),
      ),
      body,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(base.dx + w / 2, base.dy - h + 12),
        width: 18,
        height: 10,
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.35),
    );
  }
}

/// 远景云与山（缓存 Picture）
class WorldBackdrop extends PositionComponent {
  WorldBackdrop({required this.palette, required this.mapWidth})
      : super(priority: -10);

  final WorldPalette palette;
  final double mapWidth;
  ui.Picture? _picture;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _rebuild();
  }

  @override
  void onRemove() {
    _picture?.dispose();
    _picture = null;
    super.onRemove();
  }

  void _rebuild() {
    _picture?.dispose();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    _drawHills(canvas);
    _drawClouds(canvas);
    _picture = recorder.endRecording();
  }

  @override
  void render(Canvas canvas) {
    final pic = _picture;
    if (pic != null) {
      canvas.drawPicture(pic);
      return;
    }
    _drawHills(canvas);
    _drawClouds(canvas);
  }

  void _drawHills(Canvas canvas) {
    final hill = Paint()..color = palette.ground.withValues(alpha: 0.45);
    for (var x = 0.0; x < mapWidth + 400; x += 320) {
      canvas.drawPath(
        Path()
          ..moveTo(x, 380)
          ..quadraticBezierTo(x + 90, 260, x + 180, 380)
          ..quadraticBezierTo(x + 260, 460, x + 360, 380)
          ..lineTo(x + 360, 560)
          ..lineTo(x, 560)
          ..close(),
        hill,
      );
    }
  }

  void _drawClouds(Canvas canvas) {
    final cloud = Paint()..color = Colors.white.withValues(alpha: 0.85);
    for (var x = 60.0; x < mapWidth + 200; x += 240) {
      _cloud(canvas, Offset(x, 70), cloud);
      _cloud(canvas, Offset(x + 80, 110), cloud);
    }
  }

  void _cloud(Canvas canvas, Offset c, Paint paint) {
    canvas.drawCircle(c, 18, paint);
    canvas.drawCircle(Offset(c.dx + 20, c.dy + 4), 22, paint);
    canvas.drawCircle(Offset(c.dx + 44, c.dy), 16, paint);
  }
}
