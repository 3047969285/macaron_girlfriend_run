import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:macaron_girlfriend_run/theme/macaron_colors.dart';

int _sceneValue(int seed, int lane, int salt) =>
    (seed * 73 + lane * 151 + salt * 199 + (seed ~/ 3) * 17) % 997;

/// 地形块
class TerrainTile {
  const TerrainTile({
    required this.rect,
    required this.isGround,
    this.isDuckCeiling = false,
  });

  final Rect rect;
  final bool isGround;
  final bool isDuckCeiling;
}

/// 平台跳跃地形与装饰绘制（离屏 Picture 缓存，避免每帧重绘砖块）
class TerrainRenderer extends PositionComponent {
  TerrainRenderer({
    required this.solids,
    required this.palette,
    required this.mapWidth,
    required this.groundY,
    required this.sceneSeed,
  }) : super(priority: 0);

  final List<TerrainTile> solids;
  final WorldPalette palette;
  final double mapWidth;
  final double groundY;
  final int sceneSeed;

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
    _drawTerrain(canvas);
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
    _drawTerrain(canvas);
    _drawScenery(canvas);
  }

  void _drawTerrain(Canvas canvas) {
    final platformRows = <double, List<Rect>>{};
    final duckCeilingRows = <double, List<Rect>>{};
    for (final tile in solids) {
      if (tile.isGround) {
        _drawGroundBlock(canvas, tile.rect);
      } else {
        final rows = tile.isDuckCeiling ? duckCeilingRows : platformRows;
        rows.putIfAbsent(tile.rect.top, () => []).add(tile.rect);
      }
    }
    _drawPlatformRows(canvas, platformRows);
    _drawPlatformRows(canvas, duckCeilingRows, duckCeiling: true);
  }

  void _drawPlatformRows(
    Canvas canvas,
    Map<double, List<Rect>> rows, {
    bool duckCeiling = false,
  }) {
    // 把同一高度相连的瓦片画成整片软边浮台，去掉逐块描边的砖阶感。
    for (final row in rows.values) {
      row.sort((a, b) => a.left.compareTo(b.left));
      var left = row.first.left;
      var right = row.first.right;
      var top = row.first.top;
      var bottom = row.first.bottom;
      for (final rect in row.skip(1)) {
        if (rect.left <= right + 0.5) {
          right = right > rect.right ? right : rect.right;
          bottom = bottom > rect.bottom ? bottom : rect.bottom;
          continue;
        }
        _drawPlatformCluster(
          canvas,
          Rect.fromLTRB(left, top, right, bottom),
          duckCeiling: duckCeiling,
        );
        left = rect.left;
        right = rect.right;
        top = rect.top;
        bottom = rect.bottom;
      }
      _drawPlatformCluster(
        canvas,
        Rect.fromLTRB(left, top, right, bottom),
        duckCeiling: duckCeiling,
      );
    }
  }

  void _drawGroundBlock(Canvas canvas, Rect r) {
    final isSurface = r.bottom <= groundY + 0.5;
    final body = Paint()
      ..color = isSurface
          ? Color.lerp(palette.ground, palette.groundDark, 0.3)!
          : Color.lerp(palette.groundDark, palette.skyBottom, 0.16)!;
    canvas.drawRect(r, body);
    final crumbs = Paint()..color = palette.accent.withValues(alpha: 0.22);
    final tileX = (r.left / r.width).round();
    for (var i = 0; i < 2; i++) {
      final x = r.left + 8 + _sceneValue(sceneSeed, tileX, i + 7) % 32;
      final y = r.top + 16 + _sceneValue(sceneSeed, tileX, i + 11) % 24;
      canvas.drawOval(
        Rect.fromCenter(center: Offset(x, y), width: 3.5, height: 2.5),
        crumbs,
      );
    }
    if (!isSurface) return;

    if (_drawThemedSurface(canvas, r)) {
      return;
    }

    final grass = Paint()..color = palette.ground;
    canvas.drawRect(Rect.fromLTWH(r.left, r.top, r.width, 8), grass);
    final softEdge = Paint()
      ..color = Color.lerp(palette.ground, Colors.white, 0.18)!;
    for (var x = r.left + 8; x < r.right; x += 16) {
      canvas.drawOval(
        Rect.fromCenter(center: Offset(x, r.top + 5), width: 12, height: 8),
        softEdge,
      );
    }
    canvas.drawLine(
      Offset(r.left, r.top),
      Offset(r.right, r.top),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.38)
        ..strokeWidth = 1.2,
    );
  }

  void _drawPlatformCluster(Canvas canvas, Rect r, {bool duckCeiling = false}) {
    final radius = Radius.circular(
      duckCeiling
          ? 8
          : switch (palette.name) {
              '草莓甜点' || '蜜月彩虹' => 12,
              '薄荷汽水' => 9,
              '玫瑰城堡' || '蓝莓峡谷' || '焦糖矿山' => 4,
              _ => 6,
            },
    );
    final rrect = RRect.fromRectAndRadius(r, radius);
    canvas.drawRRect(
      RRect.fromRectAndRadius(r.shift(const Offset(0, 4)), radius),
      Paint()..color = palette.groundDark.withValues(alpha: 0.34),
    );
    final material = switch (palette.name) {
      '奶油草地' => const Color(0xFFC79C79),
      '草莓甜点' => const Color(0xFFEAA5BA),
      '薄荷汽水' => const Color(0xFF87CFC7),
      '香芋星空' => const Color(0xFF7760AC),
      '柠檬沙滩' => const Color(0xFFCBA672),
      '玫瑰城堡' => const Color(0xFFCC9CAE),
      '蓝莓峡谷' => const Color(0xFF738CB1),
      '焦糖矿山' => const Color(0xFFAE784F),
      '蜜月彩虹' => const Color(0xFFD8E9F6),
      _ => palette.accent,
    };
    canvas.drawRRect(
      rrect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(material, Colors.white, 0.3)!,
            material,
            Color.lerp(material, palette.groundDark, 0.32)!,
          ],
        ).createShader(r),
    );
    if (!duckCeiling) {
      canvas.save();
      canvas.clipRRect(rrect);
      _drawPlatformMaterial(canvas, r);
      canvas.restore();
    }
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.52)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );
    canvas.drawLine(
      Offset(r.left + radius.x, r.top + 3),
      Offset(r.right - radius.x, r.top + 3),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.48)
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round,
    );
    if (duckCeiling) {
      final marker = Paint()
        ..color = palette.accent.withValues(alpha: 0.76)
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round;
      for (var x = r.left + 14; x < r.right - 6; x += 24) {
        canvas.drawLine(
          Offset(x, r.bottom - 3),
          Offset(x + 8, r.bottom - 3),
          marker,
        );
      }
    }
  }

  void _drawPlatformMaterial(Canvas canvas, Rect r) {
    final seam = Paint()
      ..color = palette.groundDark.withValues(alpha: 0.42)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final cream = Paint()..color = const Color(0xFFFFF3DB);
    final center = r.center;
    switch (palette.name) {
      case '奶油草地':
        for (var x = r.left - r.height; x < r.right; x += 18) {
          canvas.drawLine(
            Offset(x, r.bottom),
            Offset(x + r.height, r.top),
            seam,
          );
          canvas.drawLine(
            Offset(x, r.top),
            Offset(x + r.height, r.bottom),
            seam,
          );
        }
        _drawMeadowTurf(canvas, r);
      case '草莓甜点':
        canvas.drawRect(Rect.fromLTWH(r.left, r.top + 20, r.width, 7), cream);
        canvas.drawRect(Rect.fromLTWH(r.left, r.top, r.width, 9), cream);
        for (var x = r.left + 8; x < r.right; x += 22) {
          canvas.drawCircle(Offset(x, r.top + 8), 5, cream);
          canvas.drawOval(
            Rect.fromCenter(
              center: Offset(x + 5, r.bottom - 10),
              width: 2.5,
              height: 4,
            ),
            Paint()..color = const Color(0xFFFFE6A7),
          );
        }
      case '薄荷汽水':
        for (var i = 0; i < (r.width / 23).ceil(); i++) {
          final x = r.left + 12 + i * 23;
          final y = r.top + 20 + (i % 2) * 12;
          canvas.drawCircle(
            Offset(x, y),
            4 + i % 3,
            Paint()
              ..color = Colors.white.withValues(alpha: 0.75)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.5,
          );
        }
        canvas.drawLine(
          Offset(r.left + 8, r.bottom - 6),
          Offset(r.left + 19, r.top + 13),
          Paint()
            ..color = Colors.white.withValues(alpha: 0.55)
            ..strokeWidth = 3,
        );
        _drawCap(canvas, r, const Color(0xFFDFFFF5), Colors.white);
      case '香芋星空':
        for (var x = r.left; x < r.right; x += 40) {
          canvas.drawPath(
            Path()
              ..moveTo(x, r.bottom)
              ..lineTo(x + 20, r.top)
              ..lineTo(x + 40, r.bottom)
              ..close(),
            Paint()..color = const Color(0xFFC7A9EA).withValues(alpha: 0.3),
          );
        }
        for (var x = r.left + 23; x < r.right; x += 48) {
          final star = Path()
            ..moveTo(x, center.dy - 7)
            ..lineTo(x + 2, center.dy - 2)
            ..lineTo(x + 7, center.dy)
            ..lineTo(x + 2, center.dy + 2)
            ..lineTo(x, center.dy + 7)
            ..lineTo(x - 2, center.dy + 2)
            ..lineTo(x - 7, center.dy)
            ..lineTo(x - 2, center.dy - 2)
            ..close();
          canvas.drawPath(star, Paint()..color = const Color(0xFFFFE8AA));
        }
      case '柠檬沙滩':
        for (var x = r.left + 24; x < r.right; x += 24) {
          canvas.drawLine(Offset(x, r.top), Offset(x, r.bottom), seam);
        }
        for (final y in [r.top + 12, r.bottom - 10]) {
          canvas.drawLine(Offset(r.left + 7, y), Offset(r.right - 7, y), seam);
        }
        for (var x = r.left + 12; x < r.right; x += 24) {
          canvas.drawCircle(
            Offset(x, r.top + 6),
            1.8,
            Paint()..color = const Color(0xFF856746),
          );
        }
      case '玫瑰城堡':
        canvas.drawLine(
          Offset(r.left, center.dy),
          Offset(r.right, center.dy),
          seam,
        );
        for (var x = r.left + 24; x < r.right; x += 48) {
          canvas.drawLine(Offset(x, r.top), Offset(x, center.dy), seam);
          canvas.drawLine(
            Offset(x + 24, center.dy),
            Offset(x + 24, r.bottom),
            seam,
          );
        }
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: center, width: 17, height: 24),
            const Radius.circular(8),
          ),
          cream,
        );
        canvas.drawCircle(center, 4, Paint()..color = palette.accent);
      case '蓝莓峡谷':
        for (var i = 0; i < 3; i++) {
          final y = r.top + 13 + i * 12;
          canvas.drawPath(
            Path()
              ..moveTo(r.left, y)
              ..lineTo(r.left + r.width * 0.35, y - 5)
              ..lineTo(r.left + r.width * 0.7, y + 2)
              ..lineTo(r.right, y - 3),
            seam,
          );
        }
        canvas.drawPath(
          Path()
            ..moveTo(center.dx + 8, r.top + 4)
            ..lineTo(center.dx, center.dy)
            ..lineTo(center.dx + 5, r.bottom),
          seam,
        );
      case '焦糖矿山':
        canvas.drawRect(Rect.fromLTWH(r.left, r.top, r.width, 7), cream);
        for (var x = r.left + 7; x < r.right; x += 36) {
          canvas.drawLine(
            Offset(x, r.top + 10),
            Offset(x + 26, r.bottom - 5),
            seam,
          );
          canvas.drawLine(
            Offset(x + 26, r.top + 10),
            Offset(x, r.bottom - 5),
            seam,
          );
        }
        final gem = Path()
          ..moveTo(center.dx, r.top + 11)
          ..lineTo(center.dx + 7, center.dy)
          ..lineTo(center.dx, r.bottom - 7)
          ..lineTo(center.dx - 7, center.dy)
          ..close();
        canvas.drawPath(gem, Paint()..color = const Color(0xFFFFD98A));
      case '蜜月彩虹':
        _drawRainbowCap(canvas, Rect.fromLTWH(r.left, r.top + 18, r.width, 10));
        for (var x = r.left + 9; x < r.right; x += 19) {
          canvas.drawCircle(
            Offset(x, r.top + 7),
            9,
            Paint()..color = Colors.white,
          );
        }
      default:
        _drawCap(canvas, r, palette.ground, palette.accent);
    }
  }

  void _drawMeadowTurf(Canvas canvas, Rect r) {
    canvas.drawRect(
      Rect.fromLTWH(r.left, r.top, r.width, 10),
      Paint()..color = const Color(0xFFB6F0C8),
    );
    final blade = Paint()
      ..color = const Color(0xFF3E9A62)
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    final tileX = (r.left / r.width).round();
    for (var i = 0; i < 4; i++) {
      final x = r.left + 6 + (i * 11 + _sceneValue(sceneSeed, tileX, i) % 8);
      final h = 7.0 + _sceneValue(sceneSeed, tileX, i + 3) % 6;
      canvas.drawLine(
        Offset(x, r.top + 8),
        Offset(x - 2, r.top + 8 - h),
        blade,
      );
      if (i == 1 && _sceneValue(sceneSeed, tileX, 9) % 3 == 0) {
        canvas.drawCircle(
          Offset(x, r.top - 2),
          3.2,
          Paint()..color = const Color(0xFFFF8FB5),
        );
        canvas.drawCircle(
          Offset(x, r.top - 2),
          1.3,
          Paint()..color = const Color(0xFFFFF1B8),
        );
      }
    }
  }

  /// 九个世界各有自己的地表。名字对不上时退回下面的通用草皮。
  bool _drawThemedSurface(Canvas canvas, Rect r) {
    switch (palette.name) {
      case '奶油草地':
        _drawMeadowTurf(canvas, r);
      case '草莓甜点':
        _drawCap(canvas, r, const Color(0xFFFFF4F8), const Color(0xFFE23D5C));
      case '薄荷汽水':
        _drawCap(canvas, r, const Color(0xFFF4FFFC), Colors.white);
        _drawFoam(canvas, r);
      case '香芋星空':
        _drawCap(canvas, r, const Color(0xFF6E5A96), const Color(0xFFFFF6C8));
      case '柠檬沙滩':
        _drawCap(canvas, r, const Color(0xFFFFF3C4), const Color(0xFFE6C35C));
      case '玫瑰城堡':
        _drawCap(canvas, r, const Color(0xFFFFD0E0), const Color(0xFFFF8FB5));
      case '蓝莓峡谷':
        _drawCap(canvas, r, const Color(0xFF5A7BC4), const Color(0xFFD6E4FF));
      case '焦糖矿山':
        _drawCap(canvas, r, const Color(0xFFC48A52), const Color(0xFFFFE6A7));
        canvas.drawRect(
          Rect.fromLTWH(r.left, r.top + 6, r.width, 3),
          Paint()..color = palette.groundDark.withValues(alpha: 0.55),
        );
      case '蜜月彩虹':
        _drawRainbowCap(canvas, r);
      default:
        return false;
    }
    return true;
  }

  void _drawCap(Canvas canvas, Rect r, Color cap, Color speck) {
    canvas.drawRect(
      Rect.fromLTWH(r.left, r.top, r.width, 10),
      Paint()..color = cap,
    );
    final tileX = (r.left / r.width).round();
    final paint = Paint()..color = speck;
    for (var i = 0; i < 3; i++) {
      final x = r.left + 8 + _sceneValue(sceneSeed, tileX, i + 2) % 32;
      canvas.drawCircle(Offset(x.toDouble(), r.top + 5), 1.7, paint);
    }
  }

  void _drawFoam(Canvas canvas, Rect r) {
    final foam = Paint()..color = Colors.white.withValues(alpha: 0.85);
    final tileX = (r.left / r.width).round();
    for (var i = 0; i < 2; i++) {
      final x = r.left + 10 + _sceneValue(sceneSeed, tileX, i + 5) % 28;
      canvas.drawCircle(Offset(x.toDouble(), r.top - 2), 3.2, foam);
    }
  }

  void _drawRainbowCap(Canvas canvas, Rect r) {
    const bands = <Color>[
      MacaronColors.rose,
      MacaronColors.lemon,
      MacaronColors.mint,
      MacaronColors.sky,
    ];
    for (var i = 0; i < bands.length; i++) {
      canvas.drawRect(
        Rect.fromLTWH(r.left, r.top + i * 2.5, r.width, 2.5),
        Paint()..color = bands[i],
      );
    }
  }

  void _drawScenery(Canvas canvas) {
    switch (palette.name) {
      case '奶油草地':
        _drawMeadowSet(canvas);
      case '草莓甜点':
        _alongGround(canvas, 176, _drawStrawberry);
      case '薄荷汽水':
        _alongGround(canvas, 188, _drawSodaCup);
      case '香芋星空':
        _alongGround(canvas, 210, _drawTaroLantern);
      case '柠檬沙滩':
        _alongGround(canvas, 200, _drawBeachUmbrella);
      case '玫瑰城堡':
        _alongGround(canvas, 280, _drawCastleBeat);
      case '蓝莓峡谷':
        _alongGround(canvas, 168, _drawBlueberryCluster);
      case '焦糖矿山':
        _alongGround(canvas, 196, _drawCaramelCrystal);
      case '蜜月彩虹':
        _alongGround(canvas, 260, _drawRainbowArch);
      default:
        _drawSharedScenery(canvas);
    }
  }

  void _alongGround(
    Canvas canvas,
    double spacing,
    void Function(Canvas canvas, double x) draw,
  ) {
    for (var x = 90.0; x < mapWidth - 40; x += spacing) {
      final jitter = (_sceneValue(sceneSeed, x.round(), 4) % 21) - 10.0;
      draw(canvas, x + jitter);
    }
  }

  void _drawSharedScenery(Canvas canvas) {
    final sectionWidth = mapWidth / 4;
    final bush = Paint()..color = palette.groundDark;
    final pipeColor = Color.lerp(palette.ground, palette.accent, 0.45)!;
    for (var section = 0; section < 4; section++) {
      final center =
          sectionWidth * (section + 0.5) +
          (_sceneValue(sceneSeed, section, 1) % 81 - 40) * 1.4;
      switch (_sceneValue(sceneSeed, section, 2) % 6) {
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
        case 4:
          _drawFlowerGarden(canvas, center);
          break;
        case 5:
          _drawRibbonGate(canvas, center);
          break;
      }
    }
  }

  void _drawMeadowSet(Canvas canvas) {
    final hill = Paint()..color = const Color(0xFFD8F8E4);
    for (var i = 0; i < 6; i++) {
      final x = mapWidth * (i + 0.5) / 6;
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(x, groundY - 18),
          width: 220,
          height: 70,
        ),
        hill,
      );
    }
    final spacing = 168.0;
    for (var x = 80.0; x < mapWidth - 40; x += spacing) {
      final jitter = (_sceneValue(sceneSeed, x.round(), 4) % 21) - 10;
      _drawFlowerGarden(canvas, x + jitter);
    }
  }

  void _drawFlowerGarden(Canvas canvas, double centerX) {
    final stem = Paint()
      ..color = const Color(0xFF579A6C)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    final colors = [
      MacaronColors.rose,
      MacaronColors.lemon,
      MacaronColors.lilac,
    ];
    for (var i = 0; i < 5; i++) {
      final x = centerX - 92 + i * 46.0;
      final height = 32.0 + (i % 3) * 11;
      final flower = Offset(x, groundY - height);
      canvas.drawLine(Offset(x, groundY - 4), flower, stem);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(x - 6, groundY - height * 0.45),
          width: 13,
          height: 6,
        ),
        Paint()..color = MacaronColors.mint,
      );
      for (var petal = 0; petal < 5; petal++) {
        final angle = petal * 1.256;
        canvas.drawCircle(
          flower + Offset(math.cos(angle) * 7, math.sin(angle) * 7),
          5,
          Paint()..color = colors[i % colors.length],
        );
      }
      canvas.drawCircle(flower, 3.3, Paint()..color = const Color(0xFFFFF1B8));
    }
  }

  void _drawRibbonGate(Canvas canvas, double centerX) {
    final path = Path()
      ..moveTo(centerX - 64, groundY)
      ..quadraticBezierTo(centerX - 64, groundY - 112, centerX, groundY - 112)
      ..quadraticBezierTo(centerX + 64, groundY - 112, centerX + 64, groundY);
    canvas.drawPath(
      path,
      Paint()
        ..color = palette.accent.withValues(alpha: 0.88)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 16
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.42)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
    for (final side in [-1.0, 1.0]) {
      final x = centerX + side * 64;
      canvas.drawCircle(
        Offset(x, groundY - 8),
        10,
        Paint()..color = palette.ground,
      );
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

  void _drawStrawberry(Canvas canvas, double x) {
    canvas.drawOval(
      Rect.fromCenter(center: Offset(x, groundY - 22), width: 28, height: 34),
      Paint()..color = const Color(0xFFE23D5C),
    );
    canvas.drawPath(
      Path()
        ..moveTo(x, groundY - 42)
        ..lineTo(x - 12, groundY - 30)
        ..lineTo(x + 12, groundY - 30)
        ..close(),
      Paint()..color = const Color(0xFF3E9A62),
    );
    final seed = Paint()..color = const Color(0xFFFFE6A7);
    for (var i = 0; i < 5; i++) {
      canvas.drawCircle(
        Offset(x - 6 + (i % 3) * 6, groundY - 28 + (i ~/ 3) * 8),
        1.4,
        seed,
      );
    }
  }

  void _drawSodaCup(Canvas canvas, double x) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x - 16, groundY - 52, 32, 52),
        const Radius.circular(8),
      ),
      Paint()..color = palette.ground.withValues(alpha: 0.95),
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(x, groundY - 52), width: 36, height: 12),
      Paint()..color = Colors.white.withValues(alpha: 0.75),
    );
    canvas.drawLine(
      Offset(x + 6, groundY - 48),
      Offset(x + 14, groundY - 78),
      Paint()
        ..color = palette.accent
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
    final bubble = Paint()..color = Colors.white.withValues(alpha: 0.85);
    canvas.drawCircle(Offset(x - 4, groundY - 36), 3, bubble);
    canvas.drawCircle(Offset(x + 5, groundY - 24), 2.2, bubble);
  }

  void _drawTaroLantern(Canvas canvas, double x) {
    canvas.drawLine(
      Offset(x, groundY - 4),
      Offset(x, groundY - 70),
      Paint()
        ..color = palette.groundDark
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(x, groundY - 86), width: 22, height: 28),
      Paint()..color = const Color(0xFFFFF1B8),
    );
    final star = Paint()
      ..color = Colors.white
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    final sx = x + 40;
    final sy = groundY - 124;
    canvas.drawLine(Offset(sx - 6, sy), Offset(sx + 6, sy), star);
    canvas.drawLine(Offset(sx, sy - 6), Offset(sx, sy + 6), star);
  }

  void _drawBeachUmbrella(Canvas canvas, double x) {
    canvas.drawLine(
      Offset(x, groundY),
      Offset(x, groundY - 64),
      Paint()
        ..color = palette.groundDark
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawPath(
      Path()
        ..moveTo(x - 36, groundY - 52)
        ..quadraticBezierTo(x, groundY - 90, x + 36, groundY - 52)
        ..close(),
      Paint()..color = palette.accent,
    );
  }

  void _drawCastleBeat(Canvas canvas, double x) {
    _drawRibbonGate(canvas, x);
    _drawFlowerGarden(canvas, x + 96);
  }

  void _drawBlueberryCluster(Canvas canvas, double x) {
    final berry = Paint()..color = const Color(0xFF3D4E9A);
    final shine = Paint()..color = Colors.white.withValues(alpha: 0.45);
    for (final o in [
      Offset(x - 10, groundY - 12),
      Offset(x + 8, groundY - 14),
      Offset(x, groundY - 26),
    ]) {
      canvas.drawCircle(o, 10, berry);
      canvas.drawCircle(o + const Offset(-3, -3), 2, shine);
    }
    canvas.drawOval(
      Rect.fromCenter(center: Offset(x, groundY - 38), width: 14, height: 6),
      Paint()..color = const Color(0xFF6FCB9A),
    );
  }

  void _drawCaramelCrystal(Canvas canvas, double x) {
    canvas.drawPath(
      Path()
        ..moveTo(x, groundY - 58)
        ..lineTo(x + 14, groundY - 18)
        ..lineTo(x, groundY - 8)
        ..lineTo(x - 14, groundY - 18)
        ..close(),
      Paint()..color = const Color(0xFFFFE6A7),
    );
    canvas.drawLine(
      Offset(x - 4, groundY - 42),
      Offset(x + 2, groundY - 22),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.75)
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
  }

  void _drawRainbowArch(Canvas canvas, double x) {
    const colors = <Color>[
      MacaronColors.rose,
      MacaronColors.lemon,
      MacaronColors.mint,
      MacaronColors.sky,
      MacaronColors.lilac,
    ];
    for (var i = 0; i < colors.length; i++) {
      final inset = i * 7.0;
      canvas.drawPath(
        Path()
          ..moveTo(x - 70 + inset, groundY)
          ..quadraticBezierTo(x, groundY - 96 + inset, x + 70 - inset, groundY),
        Paint()
          ..color = colors[i]
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6
          ..strokeCap = StrokeCap.round,
      );
    }
  }
}

/// 远景云与山（缓存 Picture）
class WorldBackdrop extends PositionComponent {
  WorldBackdrop({
    required this.palette,
    required this.mapWidth,
    required this.sceneSeed,
  }) : super(priority: -10);

  final WorldPalette palette;
  final double mapWidth;
  final int sceneSeed;
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
      final tint = tints[_sceneValue(sceneSeed, section, 4) % tints.length];
      final alpha = 0.045 + (_sceneValue(sceneSeed, section, 5) % 36) / 1000;
      canvas.drawRect(
        Rect.fromLTWH(section * sectionWidth, 0, sectionWidth, 640),
        Paint()..color = tint.withValues(alpha: alpha),
      );
    }
  }

  void _drawHills(Canvas canvas) {
    final hill = Paint()..color = palette.ground.withValues(alpha: 0.45);
    var x = -180.0 + _sceneValue(sceneSeed, 0, 6) % 240;
    for (var index = 0; x < mapWidth + 400; index++) {
      final peak = 235.0 + _sceneValue(sceneSeed, index, 7) % 86;
      canvas.drawPath(
        Path()
          ..moveTo(x, 380)
          ..quadraticBezierTo(x + 90, peak, x + 180, 380)
          ..quadraticBezierTo(x + 260, 460, x + 360, 380)
          ..lineTo(x + 360, 560)
          ..lineTo(x, 560)
          ..close(),
        hill,
      );
      x += 280 + _sceneValue(sceneSeed, index, 8) % 101;
    }
  }

  void _drawClouds(Canvas canvas) {
    final cloud = Paint()
      ..color = palette.name == '香芋星空'
          ? const Color(0xFFD4C4F5).withValues(alpha: 0.55)
          : Colors.white.withValues(alpha: 0.85);
    var x = -120.0 + _sceneValue(sceneSeed, 0, 9) % 240;
    for (var index = 0; x < mapWidth + 200; index++) {
      final y = 48.0 + _sceneValue(sceneSeed, index, 10) % 74;
      _cloud(canvas, Offset(x, y), cloud);
      if (_sceneValue(sceneSeed, index, 11) % 3 != 0) {
        _cloud(canvas, Offset(x + 80, y + 24), cloud);
      }
      x += 200 + _sceneValue(sceneSeed, index, 12) % 91;
    }
  }

  void _cloud(Canvas canvas, Offset c, Paint paint) {
    canvas.drawCircle(c, 18, paint);
    canvas.drawCircle(Offset(c.dx + 20, c.dy + 4), 22, paint);
    canvas.drawCircle(Offset(c.dx + 44, c.dy), 16, paint);
  }
}
