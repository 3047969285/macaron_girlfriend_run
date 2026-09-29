import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:macaron_girlfriend_run/theme/macaron_colors.dart';

/// 视差远近层（使用世界色板滚动）
class ParallaxLayer extends PositionComponent {
  ParallaxLayer({
    required this.mapWidth,
    required this.farColor,
    required this.midColor,
  }) : _farPaint = Paint()..color = farColor,
       _midPaint = Paint()..color = midColor,
       super(priority: -20);

  final double mapWidth;
  final Color farColor;
  final Color midColor;
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
