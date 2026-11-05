import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:macaron_girlfriend_run/data/song_world_theme.dart';
import 'package:macaron_girlfriend_run/theme/macaron_colors.dart';

/// 视差远近层（使用世界色板滚动）
class ParallaxLayer extends PositionComponent {
  ParallaxLayer({
    required this.mapWidth,
    required this.farColor,
    required this.midColor,
    this.theme,
  }) : _farPaint = Paint()..color = farColor,
       _midPaint = Paint()..color = midColor,
       super(priority: -20);

  final double mapWidth;
  final Color farColor;
  final Color midColor;
  final SongWorldTheme? theme;
  final Paint _farPaint;
  final Paint _midPaint;
  double scrollX = 0;
  double viewportWidth = 0;

  /// 由相机位置驱动
  void syncCamera(double cameraX, {required double viewportWidth}) {
    scrollX = cameraX;
    this.viewportWidth = viewportWidth > 0 ? viewportWidth : 0;
  }

  @override
  void render(Canvas canvas) {
    final farShift = scrollX * 0.15;
    final midShift = scrollX * 0.35;
    _drawFarHills(canvas, -farShift);
    _drawMidHills(canvas, -midShift);
    if (theme != null) _drawSongSkyline(canvas, -midShift, theme!);
  }

  void _drawSongSkyline(Canvas canvas, double offset, SongWorldTheme theme) {
    const spacing = 320.0;
    final start = _firstVisibleHillX(offset, spacing, -160);
    final end = _visibleHillEnd(320);
    final building = Paint()..color = Color.lerp(midColor, theme.dark, .55)!;
    final window = Paint()..color = theme.light.withValues(alpha: .65);
    final line = Paint()
      ..color = theme.dark.withValues(alpha: .72)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    for (var x = start; x < end; x += spacing) {
      canvas.save();
      canvas.translate(x, 460);
      switch (theme) {
        case SongWorldTheme.firstLove:
          canvas.drawPath(
            Path()
              ..moveTo(0, 0)
              ..lineTo(0, -105)
              ..lineTo(65, -150)
              ..lineTo(130, -105)
              ..lineTo(130, 0)
              ..close(),
            building,
          );
          for (final dx in [22.0, 78.0]) {
            canvas.drawRect(Rect.fromLTWH(dx, -93, 28, 35), window);
            canvas.drawLine(Offset(dx + 14, -93), Offset(dx + 14, -58), line);
          }
          canvas.drawRect(const Rect.fromLTWH(53, -48, 24, 48), window);
        case SongWorldTheme.whiteHorse:
          canvas.drawPath(
            Path()
              ..moveTo(0, 0)
              ..lineTo(0, -110)
              ..lineTo(20, -110)
              ..lineTo(20, -130)
              ..lineTo(37, -130)
              ..lineTo(37, -110)
              ..lineTo(95, -110)
              ..lineTo(95, -130)
              ..lineTo(112, -130)
              ..lineTo(112, -110)
              ..lineTo(132, -110)
              ..lineTo(132, 0)
              ..close(),
            building,
          );
          canvas.drawPath(
            Path()
              ..moveTo(45, 0)
              ..lineTo(45, -57)
              ..quadraticBezierTo(66, -88, 87, -57)
              ..lineTo(87, 0),
            line,
          );
          canvas.drawLine(const Offset(66, -130), const Offset(66, -176), line);
          canvas.drawPath(
            Path()
              ..moveTo(66, -174)
              ..lineTo(101, -164)
              ..lineTo(66, -154)
              ..close(),
            window,
          );
        case SongWorldTheme.reflection:
          for (var i = 0; i < 3; i++) {
            final dx = i * 48.0;
            canvas.drawPath(
              Path()
                ..moveTo(dx, 0)
                ..lineTo(dx + 5, -110 - i * 15.0)
                ..lineTo(dx + 25, -145 - i * 15.0)
                ..lineTo(dx + 42, -110 - i * 15.0)
                ..lineTo(dx + 46, 0)
                ..close(),
              building,
            );
            canvas.drawLine(
              Offset(dx + 14, -55),
              Offset(dx + 30, -100 - i * 15.0),
              Paint()
                ..color = theme.light.withValues(alpha: .45)
                ..strokeWidth = 3,
            );
          }
        case SongWorldTheme.quietLove:
          for (var i = 0; i < 4; i++) {
            final dx = i * 38.0;
            canvas.drawLine(Offset(dx, 0), Offset(dx, -82 - i * 9), line);
            canvas.drawCircle(Offset(dx, -100 - i * 9), 22, building);
            canvas.drawCircle(Offset(dx - 7, -105 - i * 9), 6, window);
          }
        case SongWorldTheme.dawn:
          for (var i = 0; i < 4; i++) {
            final dx = i * 36.0;
            final h = 90.0 + (i % 3) * 35;
            canvas.drawRect(Rect.fromLTWH(dx, -h, 32, h), building);
            for (var row = 0; row < 3; row++) {
              canvas.drawRect(
                Rect.fromLTWH(dx + 8, -h + 15 + row * 20, 6, 8),
                window,
              );
              canvas.drawRect(
                Rect.fromLTWH(dx + 20, -h + 15 + row * 20, 6, 8),
                window,
              );
            }
          }
        case SongWorldTheme.lost:
          for (var i = 0; i < 3; i++) {
            final dx = i * 55.0;
            canvas.drawLine(Offset(dx, 0), Offset(dx, -130), line);
            canvas.drawLine(Offset(dx, -130), Offset(dx + 22, -130), line);
            canvas.drawCircle(Offset(dx + 22, -123), 8, window);
            canvas.drawPath(
              Path()
                ..moveTo(dx + 16, -115)
                ..lineTo(dx - 5, -25)
                ..lineTo(dx + 50, -25)
                ..lineTo(dx + 28, -115)
                ..close(),
              Paint()..color = theme.light.withValues(alpha: .12),
            );
          }
      }
      canvas.restore();
    }
  }

  void _drawFarHills(Canvas canvas, double offset) {
    const spacing = 360.0;
    final start = _firstVisibleHillX(offset, spacing, -200);
    final end = _visibleHillEnd(400);
    for (var x = start; x < end; x += spacing) {
      canvas.drawPath(
        Path()
          ..moveTo(x, 420)
          ..quadraticBezierTo(x + 100, 280, x + 200, 420)
          ..lineTo(x + 200, 640)
          ..lineTo(x, 640)
          ..close(),
        _farPaint,
      );
    }
  }

  void _drawMidHills(Canvas canvas, double offset) {
    const spacing = 280.0;
    final start = _firstVisibleHillX(offset, spacing, -120);
    final end = _visibleHillEnd(320);
    for (var x = start; x < end; x += spacing) {
      canvas.drawPath(
        Path()
          ..moveTo(x, 460)
          ..quadraticBezierTo(x + 70, 340, x + 140, 460)
          ..quadraticBezierTo(x + 200, 500, x + 260, 460)
          ..lineTo(x + 260, 640)
          ..lineTo(x, 640)
          ..close(),
        _midPaint,
      );
    }
  }

  /// 只绘制视口内及左侧一座山的范围，避免长关每帧遍历整张地图。
  double _firstVisibleHillX(double offset, double spacing, double baseX) {
    final first = baseX + offset % spacing;
    if (viewportWidth <= 0) {
      return first;
    }
    final visibleLeft = scrollX - viewportWidth / 2 - spacing;
    if (visibleLeft <= first) {
      return first;
    }
    return first + ((visibleLeft - first) / spacing).ceil() * spacing;
  }

  double _visibleHillEnd(double mapPadding) {
    final mapEnd = mapWidth + mapPadding;
    if (viewportWidth <= 0) {
      return mapEnd;
    }
    final visibleRight = scrollX + viewportWidth / 2;
    return visibleRight < mapEnd ? visibleRight : mapEnd;
  }
}

/// 浮动积分糖（问号砖积分反馈）
class ScoreCandyBurst extends PositionComponent {
  ScoreCandyBurst({required Vector2 position})
    : super(
        position: position,
        size: Vector2.all(28),
        anchor: Anchor.center,
        priority: 80,
      );

  double _life = 0.7;

  @override
  void update(double dt) {
    _life -= dt;
    position.y -= 40 * dt;
    if (_life <= 0) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    final a = (_life / 0.7).clamp(0.0, 1.0);
    canvas.drawCircle(
      Offset(size.x / 2, size.y / 2),
      10,
      Paint()..color = MacaronColors.lemon.withValues(alpha: a),
    );
  }
}
