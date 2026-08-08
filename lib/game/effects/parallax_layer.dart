import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:macaron_girlfriend_run/theme/macaron_colors.dart';

/// 视差远近层（使用世界色板滚动）
class ParallaxLayer extends PositionComponent {
  ParallaxLayer({
    required this.mapWidth,
    required this.farColor,
    required this.midColor,
  }) : super(priority: -20);

  final double mapWidth;
  final Color farColor;
  final Color midColor;
  double scrollX = 0;

  /// 由相机位置驱动
  void syncCamera(double cameraX) {
    scrollX = cameraX;
  }

  @override
  void render(Canvas canvas) {
    final farShift = scrollX * 0.15;
    final midShift = scrollX * 0.35;
    _drawFarHills(canvas, -farShift);
    _drawMidHills(canvas, -midShift);
  }

  void _drawFarHills(Canvas canvas, double offset) {
    final paint = Paint()..color = farColor;
    for (var x = -200.0 + offset % 360; x < mapWidth + 400; x += 360) {
      canvas.drawPath(
        Path()
          ..moveTo(x, 420)
          ..quadraticBezierTo(x + 100, 280, x + 200, 420)
          ..lineTo(x + 200, 640)
          ..lineTo(x, 640)
          ..close(),
        paint,
      );
    }
  }

  void _drawMidHills(Canvas canvas, double offset) {
    final paint = Paint()..color = midColor;
    for (var x = -120.0 + offset % 280; x < mapWidth + 320; x += 280) {
      canvas.drawPath(
        Path()
          ..moveTo(x, 460)
          ..quadraticBezierTo(x + 70, 340, x + 140, 460)
          ..quadraticBezierTo(x + 200, 500, x + 260, 460)
          ..lineTo(x + 260, 640)
          ..lineTo(x, 640)
          ..close(),
        paint,
      );
    }
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
