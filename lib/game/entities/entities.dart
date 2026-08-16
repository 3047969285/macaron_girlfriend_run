import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:macaron_girlfriend_run/data/enemy_kind.dart';
import 'package:macaron_girlfriend_run/theme/macaron_colors.dart';

/// 马卡龙金币
class MacaronCoin extends PositionComponent {
  MacaronCoin({required Vector2 position})
      : super(
          position: position,
          size: Vector2.all(34),
          anchor: Anchor.center,
          priority: 50,
        );

  bool collected = false;
  double _spin = 0;
  double _bob = 0;

  @override
  void update(double dt) {
    _spin += dt * 5;
    _bob += dt * 6;
  }

  @override
  void render(Canvas canvas) {
    if (collected) {
      return;
    }
    final bobY = math.sin(_bob) * 3;
    final scaleX =
        (0.55 + 0.45 * (1 + (_spin % 3.14 - 1.57).abs() / 1.57)).clamp(0.35, 1.0);
    canvas.save();
    canvas.translate(size.x / 2, size.y / 2 + bobY);
    canvas.scale(scaleX, 1);
    canvas.drawCircle(Offset.zero, size.x * 0.44, Paint()..color = MacaronColors.lemon);
    canvas.drawCircle(Offset.zero, size.x * 0.3, Paint()..color = MacaronColors.blush);
    canvas.drawCircle(
      const Offset(-4, -4),
      3,
      Paint()..color = Colors.white.withValues(alpha: 0.6),
    );
    canvas.restore();
  }
}

/// 问号砖块
class QuestionBlock extends PositionComponent {
  QuestionBlock({required Vector2 position})
      : super(
          position: position,
          size: Vector2.all(48),
          anchor: Anchor.topLeft,
          priority: 20,
        );

  bool used = false;
  double _bounce = 0;

  void hit() {
    if (used) {
      return;
    }
    used = true;
    _bounce = 1;
  }

  @override
  void update(double dt) {
    if (_bounce > 0) {
      _bounce = (_bounce - dt * 4).clamp(0.0, 1.0);
    }
  }

  @override
  void render(Canvas canvas) {
    final lift = math.sin(_bounce * math.pi) * 8;
    final rect = Rect.fromLTWH(0, -lift, size.x, size.y);
    final color = used ? const Color(0xFFBCAAA4) : MacaronColors.lemon;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(6)),
      Paint()..color = color,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(6)),
      Paint()
        ..color = MacaronColors.cocoa
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
    if (!used) {
      // 用路径画问号，避免每帧 TextPainter 布局卡顿
      final q = Paint()
        ..color = MacaronColors.cocoa
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.2
        ..strokeCap = StrokeCap.round;
      final cx = size.x / 2;
      final cy = 18 - lift;
      canvas.drawArc(
        Rect.fromCenter(center: Offset(cx, cy - 4), width: 14, height: 14),
        -2.6,
        3.4,
        false,
        q,
      );
      canvas.drawLine(Offset(cx, cy + 4), Offset(cx, cy + 9), q);
      canvas.drawCircle(
        Offset(cx, cy + 14),
        2.2,
        Paint()..color = MacaronColors.cocoa,
      );
    }
  }
}

/// 超级跳道具
class PowerMacaron extends PositionComponent {
  PowerMacaron({required Vector2 position})
      : super(
          position: position,
          size: Vector2.all(36),
          anchor: Anchor.center,
          priority: 55,
        );

  bool collected = false;
  double _spin = 0;

  @override
  void update(double dt) {
    _spin += dt * 3;
  }

  @override
  void render(Canvas canvas) {
    if (collected) {
      return;
    }
    canvas.save();
    canvas.translate(size.x / 2, size.y / 2 + math.sin(_spin) * 4);
    canvas.drawCircle(Offset.zero, 16, Paint()..color = MacaronColors.lilac);
    canvas.drawCircle(Offset.zero, 10, Paint()..color = Colors.white);
    canvas.drawCircle(Offset.zero, 6, Paint()..color = MacaronColors.rose);
    canvas.restore();
  }
}

/// 生命心
class LifeHeart extends PositionComponent {
  LifeHeart({required Vector2 position})
      : super(
          position: position,
          size: Vector2.all(32),
          anchor: Anchor.center,
          priority: 55,
        );

  bool collected = false;
  double _bob = 0;

  @override
  void update(double dt) {
    _bob += dt * 5;
  }

  @override
  void render(Canvas canvas) {
    if (collected) {
      return;
    }
    canvas.save();
    canvas.translate(size.x / 2, size.y / 2 + math.sin(_bob) * 3);
    final p = Path()
      ..moveTo(0, 6)
      ..cubicTo(-14, -6, -8, -16, 0, -8)
      ..cubicTo(8, -16, 14, -6, 0, 6);
    canvas.drawPath(p, Paint()..color = MacaronColors.rose);
    canvas.restore();
  }
}

/// 弹簧垫
class SpringPad extends PositionComponent {
  SpringPad({required Vector2 position})
      : super(
          position: position,
          size: Vector2(48, 20),
          anchor: Anchor.topLeft,
          priority: 25,
        );

  double _squash = 0;

  void bounce() {
    _squash = 1;
  }

  @override
  void update(double dt) {
    if (_squash > 0) {
      _squash = (_squash - dt * 3).clamp(0.0, 1.0);
    }
  }

  @override
  void render(Canvas canvas) {
    final h = size.y * (1 - _squash * 0.4);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, size.y - h, size.x, h),
        const Radius.circular(6),
      ),
      Paint()..color = MacaronColors.mint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(4, size.y - h + 4, size.x - 8, 6),
        const Radius.circular(3),
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.5),
    );
  }
}

/// 软萌小怪
class SoftEnemy extends PositionComponent {
  SoftEnemy({
    required Vector2 position,
    required this.leftBound,
    required this.rightBound,
    this.speed = 88,
    EnemyKind kind = EnemyKind.walker,
  })  : kind = kind,
        hitPoints = kind == EnemyKind.bruiser ? 2 : 1,
        _baseY = position.y,
        _hopVy = kind == EnemyKind.hopper ? -320.0 : 0.0,
        super(
          position: position,
          size: kind == EnemyKind.bruiser ? Vector2(52, 44) : Vector2(42, 36),
          anchor: Anchor.bottomCenter,
          priority: 40,
        );

  final double leftBound;
  final double rightBound;
  final double speed;
  final EnemyKind kind;
  final double _baseY;
  int hitPoints;
  double dir = 1;
  double _wobble = 0;
  double _hopVy = 0;
  double _flash = 0;
  bool dead = false;
  /// 镜头外跳过移动，减负长关
  bool simActive = true;

  /// 踩踏一次返回是否击杀
  bool takeStomp() {
    if (dead) {
      return true;
    }
    hitPoints--;
    _flash = 0.35;
    if (hitPoints <= 0) {
      dead = true;
      return true;
    }
    return false;
  }

  @override
  void update(double dt) {
    if (dead || !simActive) {
      return;
    }
    _wobble += dt * 8;
    if (_flash > 0) {
      _flash -= dt;
    }
    final move = speed * (kind == EnemyKind.bruiser ? 0.72 : 1.0);
    position.x += dir * move * dt;
    if (position.x < leftBound) {
      position.x = leftBound;
      dir = 1;
    } else if (position.x > rightBound) {
      position.x = rightBound;
      dir = -1;
    }
    if (kind == EnemyKind.hopper) {
      _hopVy += 1800 * dt;
      position.y += _hopVy * dt;
      if (_hopVy > 0 && position.y >= _baseY) {
        position.y = _baseY;
        _hopVy = -420;
      }
    }
  }

  Color get _bodyColor {
    switch (kind) {
      case EnemyKind.hopper:
        return const Color(0xFFFFB74D);
      case EnemyKind.bruiser:
        return const Color(0xFFE57373);
      case EnemyKind.walker:
        return const Color(0xFFFF8A80);
    }
  }

  @override
  void render(Canvas canvas) {
    if (dead) {
      return;
    }
    if (_flash > 0 && (_flash * 18).floor().isOdd) {
      return;
    }
    final squash = 1 + math.sin(_wobble) * 0.06;
    canvas.save();
    canvas.translate(size.x / 2, size.y);
    canvas.scale(dir * squash, 1 / squash);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(0, -size.y * 0.45),
        width: size.x,
        height: size.y * 0.9,
      ),
      Paint()..color = _bodyColor,
    );
    canvas.drawCircle(Offset(-8, -size.y * 0.55), 5, Paint()..color = Colors.white);
    canvas.drawCircle(Offset(8, -size.y * 0.55), 5, Paint()..color = Colors.white);
    canvas.drawCircle(Offset(-8, -size.y * 0.55), 2.5, Paint()..color = MacaronColors.cocoa);
    canvas.drawCircle(Offset(8, -size.y * 0.55), 2.5, Paint()..color = MacaronColors.cocoa);
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(-10, -4), width: 12, height: 8),
      Paint()..color = const Color(0xFFE57373),
    );
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(10, -4), width: 12, height: 8),
      Paint()..color = const Color(0xFFE57373),
    );
    if (kind == EnemyKind.bruiser) {
      for (var i = 0; i < hitPoints; i++) {
        canvas.drawCircle(
          Offset(-6 + i * 12.0, -size.y * 0.82),
          4,
          Paint()..color = MacaronColors.lemon,
        );
      }
    }
    canvas.restore();
  }
}

/// 世界 Boss（需多次踩踏，半血进入狂暴）
class MacaronBoss extends PositionComponent {
  MacaronBoss({
    required Vector2 position,
    required this.leftBound,
    required this.rightBound,
    this.maxHp = 3,
  })  : hp = maxHp,
        _baseY = position.y,
        super(
          position: position,
          size: Vector2(86, 72),
          anchor: Anchor.bottomCenter,
          priority: 45,
        );

  final double leftBound;
  final double rightBound;
  final int maxHp;
  final double _baseY;
  int hp;
  double dir = -1;
  double _wobble = 0;
  double _flash = 0;
  double _jumpCd = 1.2;
  double _vy = 0;
  bool dead = false;
  bool enraged = false;
  bool isSlamming = false;

  /// 踩踏一次返回是否刚进入狂暴
  bool stompHit() {
    if (dead) {
      return false;
    }
    hp--;
    _flash = 0.35;
    var justEnraged = false;
    if (!enraged && hp <= (maxHp / 2).ceil()) {
      enraged = true;
      justEnraged = true;
      _jumpCd = 0.2;
    }
    if (hp <= 0) {
      dead = true;
    }
    return justEnraged;
  }

  @override
  void update(double dt) {
    if (dead) {
      return;
    }
    _wobble += dt * (enraged ? 8 : 5);
    if (_flash > 0) {
      _flash -= dt;
    }
    final speed = enraged ? 125.0 : 70.0;
    position.x += dir * speed * dt;
    if (position.x < leftBound) {
      position.x = leftBound;
      dir = 1;
    } else if (position.x > rightBound) {
      position.x = rightBound;
      dir = -1;
    }

    if (enraged) {
      _jumpCd -= dt;
      if (_jumpCd <= 0 && !isSlamming) {
        isSlamming = true;
        _vy = -780;
        _jumpCd = 2.2;
      }
      if (isSlamming) {
        _vy += 2400 * dt;
        position.y += _vy * dt;
        if (position.y >= _baseY) {
          position.y = _baseY;
          _vy = 0;
          isSlamming = false;
        }
      }
    } else {
      position.y = _baseY;
    }
  }

  @override
  void render(Canvas canvas) {
    if (dead) {
      return;
    }
    if (_flash > 0 && (_flash * 20).floor().isOdd) {
      return;
    }
    final squash = 1 + math.sin(_wobble) * 0.05;
    canvas.save();
    canvas.translate(size.x / 2, size.y);
    canvas.scale((dir >= 0 ? 1.0 : -1.0) * squash, 1 / squash);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(0, -size.y * 0.42),
          width: size.x,
          height: size.y * 0.85,
        ),
        const Radius.circular(18),
      ),
      Paint()..color = enraged ? MacaronColors.rose : MacaronColors.lilac,
    );
    canvas.drawCircle(Offset(-14, -size.y * 0.55), 8, Paint()..color = Colors.white);
    canvas.drawCircle(Offset(14, -size.y * 0.55), 8, Paint()..color = Colors.white);
    canvas.drawCircle(Offset(-14, -size.y * 0.55), 4, Paint()..color = MacaronColors.cocoa);
    canvas.drawCircle(Offset(14, -size.y * 0.55), 4, Paint()..color = MacaronColors.cocoa);
    canvas.drawCircle(
      Offset(0, -size.y * 0.78),
      10,
      Paint()..color = enraged ? const Color(0xFFFF5252) : MacaronColors.lemon,
    );
    for (var i = 0; i < maxHp; i++) {
      canvas.drawCircle(
        Offset(-18 + i * 18.0, -size.y - 8),
        5,
        Paint()
          ..color = i < hp ? MacaronColors.rose : Colors.white.withValues(alpha: 0.35),
      );
    }
    canvas.restore();
  }
}

/// 检查点旗
class CheckpointPad extends PositionComponent {
  CheckpointPad({required Vector2 position})
      : super(
          position: position,
          size: Vector2(36, 72),
          anchor: Anchor.bottomCenter,
          priority: 28,
        );

  bool activated = false;
  double _wave = 0;

  void activate() {
    activated = true;
  }

  @override
  void update(double dt) {
    _wave += dt * 3;
  }

  @override
  void render(Canvas canvas) {
    canvas.drawRect(
      Rect.fromLTWH(size.x * 0.42, 0, 5, size.y),
      Paint()..color = MacaronColors.cocoa,
    );
    final tip = math.sin(_wave) * 3;
    canvas.drawPath(
      Path()
        ..moveTo(size.x * 0.5, 8)
        ..lineTo(size.x * 0.95 + tip, 22)
        ..lineTo(size.x * 0.5, 36)
        ..close(),
      Paint()..color = activated ? MacaronColors.mint : MacaronColors.sky,
    );
  }
}

/// 终点旗杆
class GoalFlag extends PositionComponent {
  GoalFlag({required Vector2 position})
      : super(
          position: position,
          size: Vector2(40, 96),
          anchor: Anchor.bottomCenter,
          priority: 30,
        );

  double _wave = 0;

  @override
  void update(double dt) {
    _wave += dt * 3;
  }

  @override
  void render(Canvas canvas) {
    canvas.drawRect(
      Rect.fromLTWH(size.x * 0.42, 0, 6, size.y),
      Paint()..color = MacaronColors.cocoa,
    );
    final tip = math.sin(_wave) * 4;
    canvas.drawPath(
      Path()
        ..moveTo(size.x * 0.5, 6)
        ..lineTo(size.x * 0.98 + tip, 24)
        ..lineTo(size.x * 0.5, 42)
        ..close(),
      Paint()..color = MacaronColors.rose,
    );
    canvas.drawCircle(
      Offset(size.x * 0.48, size.y - 10),
      12,
      Paint()..color = MacaronColors.lemon,
    );
  }
}
