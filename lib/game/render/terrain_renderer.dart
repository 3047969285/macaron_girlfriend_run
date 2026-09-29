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
    required this.sceneVariant,
  }) : super(priority: 0);

  final List<TerrainTile> solids;
  final WorldPalette palette;
  final double mapWidth;
  final double groundY;
  final int sceneVariant;

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
    final sectionWidth = mapWidth / 4;
    final bush = Paint()..color = palette.groundDark;
    final pipeColor = Color.lerp(palette.ground, palette.accent, 0.45)!;
    for (var section = 0; section < 4; section++) {
      final center = sectionWidth * (section + 0.5);
      switch ((sceneVariant + section) % 4) {
        case 0:
          _drawBush(canvas, Offset(center - 170, groundY - 4), bush);
          _drawMacaronPipe(canvas, Offset(center - 22, groundY), pipeColor);
          _drawBush(canvas, Offset(center + 150, groundY - 4), bush);
          break;
        case 1:
          _drawCupcake(canvas, Offset(center, groundY - 2));
          _drawCupcake(canvas, Offset(center + 210, groundY - 2));
          break;
        case 2:
          _drawLollipop(canvas, Offset(center - 120, groundY - 4));
          _drawLollipop(canvas, Offset(center + 120, groundY - 4));
          break;
        case 3:
          _drawCandyCastle(canvas, center);
          break;
      }
    }
  }

  void _drawCandyCastle(Canvas canvas, double centerX) {
    final icing = Paint()..color = palette.accent.withValues(alpha: 0.88);
    final trim = Paint()..color = palette.ground.withValues(alpha: 0.95);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(centerX - 46, groundY - 58, 92, 58),
        const Radius.circular(8),
      ),
      icing,
    );
    for (final side in [-1.0, 1.0]) {
      final towerX = centerX + side * 42 - 15;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(towerX, groundY - 84, 30, 84),
          const Radius.circular(7),
        ),
        icing,
      );
      canvas.drawPath(
        Path()
          ..moveTo(towerX - 3, groundY - 82)
          ..lineTo(towerX + 15, groundY - 106)
          ..lineTo(towerX + 33, groundY - 82)
          ..close(),
        trim,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(towerX + 9, groundY - 58, 12, 19),
          const Radius.circular(6),
        ),
        trim,
      );
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(centerX - 11, groundY - 30, 22, 30),
        const Radius.circular(11),
      ),
      trim,
    );
  }

  void _drawCupcake(Canvas canvas, Offset base) {
    final wrapper = Paint()..color = palette.accent;
    canvas.drawPath(
      Path()
        ..moveTo(base.dx - 22, base.dy - 26)
        ..lineTo(base.dx + 22, base.dy - 26)
        ..lineTo(base.dx + 16, base.dy - 3)
        ..lineTo(base.dx - 16, base.dy - 3)
        ..close(),
      wrapper,
    );
    final icing = Paint()..color = palette.ground.withValues(alpha: 0.95);
    canvas.drawCircle(Offset(base.dx - 10, base.dy - 31), 14, icing);
    canvas.drawCircle(Offset(base.dx + 8, base.dy - 34), 17, icing);
    canvas.drawCircle(Offset(base.dx + 21, base.dy - 26), 11, icing);
    canvas.drawCircle(
      Offset(base.dx + 3, base.dy - 40),
      4,
      Paint()..color = MacaronColors.rose,
    );
  }

  void _drawLollipop(Canvas canvas, Offset base) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(base.dx - 2, base.dy - 42, 4, 42),
        const Radius.circular(2),
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.8),
    );
    final candy = Offset(base.dx, base.dy - 52);
    canvas.drawCircle(candy, 18, Paint()..color = palette.accent);
    canvas.drawCircle(
      candy,
      11,
      Paint()
        ..color = palette.ground
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4,
    );
    canvas.drawCircle(
      candy + const Offset(-5, -6),
      3,
      Paint()..color = Colors.white.withValues(alpha: 0.85),
    );
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
  WorldBackdrop({
    required this.palette,
    required this.mapWidth,
    required this.sceneVariant,
  }) : super(priority: -10);

  final WorldPalette palette;
  final double mapWidth;
  final int sceneVariant;
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
    _drawSceneTints(canvas);
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
    _drawSceneTints(canvas);
    _drawHills(canvas);
    _drawClouds(canvas);
  }

  void _drawSceneTints(Canvas canvas) {
    final tints = [
      palette.skyTop,
      palette.accent,
      palette.parallaxMid,
      MacaronColors.lemon,
    ];
    final sectionWidth = mapWidth / 4;
    for (var section = 0; section < 4; section++) {
      final tint = tints[(sceneVariant + section) % tints.length];
      canvas.drawRect(
        Rect.fromLTWH(section * sectionWidth, 0, sectionWidth, 640),
        Paint()..color = tint.withValues(alpha: 0.075),
      );
    }
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
