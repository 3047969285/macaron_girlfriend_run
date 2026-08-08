import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:macaron_girlfriend_run/theme/macaron_colors.dart';

/// 单颗特效粒子
class _FxParticle {
  _FxParticle({
    required this.position,
    required this.velocity,
    required this.color,
    required this.size,
    required this.life,
    this.gravity = 520,
  });

  Vector2 position;
  Vector2 velocity;
  Color color;
  double size;
  double life;
  final double gravity;
}

/// 马卡龙风格粒子特效层
class FxLayer extends PositionComponent {
  FxLayer() : super(priority: 200);

  final List<_FxParticle> _particles = [];
  final List<_FxRing> _rings = [];
  final List<_FxLabel> _labels = [];
  final math.Random _rng = math.Random();

  /// 起跳尘土
  void jumpDust(Vector2 at, {Color? tint}) {
    _spawn(
      at + Vector2(0, 4),
      count: 10,
      speed: 140,
      spread: math.pi,
      baseDir: -math.pi / 2,
      colors: [
        tint ?? MacaronColors.blush,
        MacaronColors.cream,
        Colors.white.withValues(alpha: 0.8),
      ],
      sizeMin: 3,
      sizeMax: 7,
      life: 0.45,
      gravity: 680,
    );
  }

  /// 吃金币闪光
  void coinSparkle(Vector2 at) {
    _spawn(
      at,
      count: 14,
      speed: 200,
      spread: math.pi * 2,
      colors: [
        MacaronColors.lemon,
        MacaronColors.blush,
        Colors.white,
      ],
      sizeMin: 2,
      sizeMax: 6,
      life: 0.55,
    );
  }

  /// 踩怪击杀：粒子 + 冲击波 + KO 字
  void stompKill(Vector2 at) {
    _spawn(
      at,
      count: 28,
      speed: 320,
      spread: math.pi * 1.6,
      baseDir: -math.pi / 2,
      colors: [
        MacaronColors.mint,
        MacaronColors.rose,
        MacaronColors.lemon,
        Colors.white,
      ],
      sizeMin: 4,
      sizeMax: 12,
      life: 0.75,
      gravity: 620,
    );
    _rings.add(_FxRing(center: at.clone(), life: 0.38, maxRadius: 56));
    _labels.add(
      _FxLabel(
        text: 'KO!',
        position: at + Vector2(-18, -36),
        life: 0.85,
        color: MacaronColors.rose,
      ),
    );
    _labels.add(
      _FxLabel(
        text: '★',
        position: at + Vector2(12, -48),
        life: 0.7,
        color: MacaronColors.lemon,
        size: 22,
      ),
    );
  }

  /// 踩怪星星
  void stompBurst(Vector2 at) {
    stompKill(at);
  }

  /// 顶砖碎屑
  void blockBump(Vector2 at) {
    _spawn(
      at + Vector2(0, -8),
      count: 8,
      speed: 120,
      spread: math.pi * 0.8,
      baseDir: -math.pi / 2,
      colors: [
        MacaronColors.lemon,
        const Color(0xFFBCAAA4),
      ],
      sizeMin: 4,
      sizeMax: 9,
      life: 0.5,
      gravity: 900,
    );
  }

  /// 道具吸收
  void powerUp(Vector2 at) {
    _spawn(
      at,
      count: 22,
      speed: 180,
      spread: math.pi * 2,
      colors: [
        MacaronColors.lilac,
        MacaronColors.rose,
        Colors.white,
      ],
      sizeMin: 3,
      sizeMax: 10,
      life: 0.75,
    );
  }

  /// 弹簧弹起
  void springPop(Vector2 at) {
    _spawn(
      at,
      count: 12,
      speed: 220,
      spread: math.pi,
      baseDir: -math.pi / 2,
      colors: [
        MacaronColors.mint,
        Colors.white,
      ],
      sizeMin: 4,
      sizeMax: 8,
      life: 0.5,
    );
  }

  /// 外观跑步拖尾
  void softTrail(Vector2 at, Color color) {
    _spawn(
      at,
      count: 4,
      speed: 40,
      spread: math.pi * 0.6,
      baseDir: math.pi,
      colors: [
        color.withValues(alpha: 0.85),
        Colors.white.withValues(alpha: 0.7),
      ],
      sizeMin: 3,
      sizeMax: 7,
      life: 0.35,
      gravity: 80,
    );
  }

  /// 通关彩带
  void winConfetti(Vector2 at) {
    _spawn(
      at,
      count: 36,
      speed: 320,
      spread: math.pi * 2,
      colors: [
        MacaronColors.rose,
        MacaronColors.lemon,
        MacaronColors.lilac,
        MacaronColors.mint,
        MacaronColors.blush,
      ],
      sizeMin: 4,
      sizeMax: 11,
      life: 1.2,
      gravity: 420,
    );
  }

  void _spawn(
    Vector2 origin, {
    required int count,
    required double speed,
    required double spread,
    required List<Color> colors,
    required double sizeMin,
    required double sizeMax,
    required double life,
    double baseDir = 0,
    double gravity = 520,
  }) {
    for (var i = 0; i < count; i++) {
      final ang = baseDir + (_rng.nextDouble() - 0.5) * spread;
      final spd = speed * (0.45 + _rng.nextDouble() * 0.75);
      _particles.add(
        _FxParticle(
          position: origin.clone(),
          velocity: Vector2(math.cos(ang) * spd, math.sin(ang) * spd),
          color: colors[_rng.nextInt(colors.length)],
          size: sizeMin + _rng.nextDouble() * (sizeMax - sizeMin),
          life: life * (0.7 + _rng.nextDouble() * 0.5),
          gravity: gravity,
        ),
      );
    }
  }

  @override
  void update(double dt) {
    for (final p in _particles) {
      p.life -= dt;
      p.velocity.y += p.gravity * dt;
      p.position += p.velocity * dt;
    }
    _particles.removeWhere((p) => p.life <= 0);
    for (final r in _rings) {
      r.life -= dt;
      r.radius += dt * r.maxRadius * 2.8;
    }
    _rings.removeWhere((r) => r.life <= 0);
    for (final l in _labels) {
      l.life -= dt;
      l.position.y -= dt * 72;
    }
    _labels.removeWhere((l) => l.life <= 0);
  }

  @override
  void render(Canvas canvas) {
    for (final r in _rings) {
      final alpha = (r.life * 2.8).clamp(0.0, 1.0);
      final paint = Paint()
        ..color = MacaronColors.rose.withValues(alpha: alpha * 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4;
      canvas.drawCircle(
        Offset(r.center.x, r.center.y),
        r.radius,
        paint,
      );
    }
    for (final p in _particles) {
      final alpha = (p.life * 2.5).clamp(0.0, 1.0);
      final paint = Paint()..color = p.color.withValues(alpha: alpha);
      canvas.drawCircle(
        Offset(p.position.x, p.position.y),
        p.size,
        paint,
      );
    }
    for (final l in _labels) {
      final alpha = (l.life * 1.8).clamp(0.0, 1.0);
      final tp = TextPainter(
        text: TextSpan(
          text: l.text,
          style: TextStyle(
            fontSize: l.size,
            fontWeight: FontWeight.w900,
            color: l.color.withValues(alpha: alpha),
            shadows: [
              Shadow(
                color: Colors.white.withValues(alpha: alpha * 0.8),
                blurRadius: 6,
              ),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(l.position.x, l.position.y));
    }
  }
}

class _FxRing {
  _FxRing({
    required this.center,
    required this.life,
    required this.maxRadius,
  }) : radius = 8;

  final Vector2 center;
  double life;
  final double maxRadius;
  double radius;
}

class _FxLabel {
  _FxLabel({
    required this.text,
    required this.position,
    required this.life,
    required this.color,
    this.size = 28,
  });

  final String text;
  Vector2 position;
  double life;
  final Color color;
  final double size;
}

/// 远景漂浮光点
class AmbientSparkles extends PositionComponent {
  AmbientSparkles({required this.mapWidth, required this.tint})
      : super(priority: -5);

  final double mapWidth;
  final Color tint;
  final List<_Spark> _dots = [];
  final math.Random _rng = math.Random();
  double _acc = 0;

  @override
  Future<void> onLoad() async {
    for (var i = 0; i < 28; i++) {
      _dots.add(_makeSpark());
    }
  }

  _Spark _makeSpark() {
    return _Spark(
      x: _rng.nextDouble() * mapWidth,
      y: 40 + _rng.nextDouble() * 220,
      phase: _rng.nextDouble() * math.pi * 2,
      size: 2 + _rng.nextDouble() * 3,
    );
  }

  @override
  void update(double dt) {
    _acc += dt;
    for (final d in _dots) {
      d.phase += dt * (1.2 + d.size * 0.15);
      d.y += math.sin(d.phase) * dt * 8;
    }
    if (_acc > 2.5) {
      _acc = 0;
      final s = _dots[_rng.nextInt(_dots.length)];
      s.x = _rng.nextDouble() * mapWidth;
      s.y = 50 + _rng.nextDouble() * 180;
    }
  }

  @override
  void render(Canvas canvas) {
    for (final d in _dots) {
      final a = (0.25 + 0.35 * (0.5 + 0.5 * math.sin(d.phase))).clamp(0.0, 1.0);
      canvas.drawCircle(
        Offset(d.x, d.y),
        d.size,
        Paint()..color = tint.withValues(alpha: a),
      );
    }
  }
}

class _Spark {
  _Spark({
    required this.x,
    required this.y,
    required this.phase,
    required this.size,
  });

  double x;
  double y;
  double phase;
  double size;
}
