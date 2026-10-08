import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:macaron_girlfriend_run/data/enemy_kind.dart';
import 'package:macaron_girlfriend_run/data/game_models.dart';
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
    final scaleX = (0.55 + 0.45 * (1 + (_spin % 3.14 - 1.57).abs() / 1.57))
        .clamp(0.35, 1.0);
    canvas.save();
    canvas.translate(size.x / 2, size.y / 2 + bobY);
    canvas.scale(scaleX, 1);
    canvas.drawCircle(
      Offset.zero,
      size.x * 0.44,
      Paint()..color = MacaronColors.lemon,
    );
    canvas.drawCircle(
      Offset.zero,
      size.x * 0.3,
      Paint()..color = MacaronColors.blush,
    );
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
    required this.difficulty,
    this.speed = 88,
    this.onSkillCue,
    this.onShoot,
    this.onLayTrap,
    EnemyKind kind = EnemyKind.walker,
  }) : kind = kind,
       hitPoints = kind == EnemyKind.bruiser ? 2 : 1,
       _baseY = position.y,
       _hopVy = kind == EnemyKind.hopper ? -320.0 : 0.0,
       super(
         position: position,
         size: kind == EnemyKind.bruiser ? Vector2(52, 44) : Vector2(42, 36),
         anchor: Anchor.bottomCenter,
         priority: 40,
       ) {
    _skillCooldown =
        GameConstants.enemySkillCooldownFor(difficulty, kind) * 0.65 +
        position.x.abs() % 80 / 200;
    _justLanded = kind != EnemyKind.hopper;
  }

  final double leftBound;
  final double rightBound;
  final int difficulty;
  final double speed;
  final EnemyKind kind;
  final double _baseY;
  final void Function(Vector2 at, EnemyKind kind)? onSkillCue;
  final void Function(Vector2 at, double direction)? onShoot;
  final void Function(Vector2 at)? onLayTrap;
  int hitPoints;
  double dir = 1;
  double _wobble = 0;
  double _hopVy = 0;
  double _flash = 0;
  double _skillCooldown = 2;
  double _warningTimer = 0;
  double _chargeTimer = 0;
  double _chargeDir = 1;
  double? targetX;
  double? targetY;
  bool _justLanded = true;
  bool _pouncing = false;
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
    _skillCooldown = (_skillCooldown - dt).clamp(0.0, 10.0);

    if (_warningTimer > 0) {
      _warningTimer = (_warningTimer - dt).clamp(0.0, 2.0);
      if (_warningTimer > 0) {
        return;
      }
      switch (kind) {
        case EnemyKind.walker:
          onShoot?.call(
            position + Vector2(dir * size.x * 0.55, -size.y * 0.58),
            dir,
          );
          _skillCooldown = GameConstants.enemySkillCooldownFor(
            difficulty,
            kind,
          );
        case EnemyKind.hopper:
          _hopVy = GameConstants.enemyPounceVelocityFor(difficulty);
          _justLanded = false;
          _pouncing = true;
          _skillCooldown = GameConstants.enemySkillCooldownFor(
            difficulty,
            kind,
          );
        case EnemyKind.bruiser:
          _chargeDir = dir;
          _chargeTimer = 0.72;
          _skillCooldown = GameConstants.enemySkillCooldownFor(
            difficulty,
            kind,
          );
        case EnemyKind.trapper:
          onLayTrap?.call(position.clone());
          _skillCooldown = GameConstants.enemySkillCooldownFor(
            difficulty,
            kind,
          );
      }
      if (kind != EnemyKind.hopper) {
        return;
      }
    }

    if (_chargeTimer > 0) {
      _chargeTimer = (_chargeTimer - dt).clamp(0.0, 1.0);
      position.x +=
          _chargeDir *
          speed *
          GameConstants.enemyChargeSpeedMultiplierFor(difficulty) *
          dt;
      if (position.x < leftBound) {
        position.x = leftBound;
        _chargeTimer = 0;
      } else if (position.x > rightBound) {
        position.x = rightBound;
        _chargeTimer = 0;
      }
      return;
    }

    final tx = targetX;
    final ty = targetY;
    if (tx != null &&
        ty != null &&
        _skillCooldown <= 0 &&
        (ty - position.y).abs() < 150) {
      final dx = tx - position.x;
      final distance = dx.abs();
      final canUseSkill = switch (kind) {
        EnemyKind.walker =>
          distance >= 100 &&
              distance <= GameConstants.enemySkillRangeFor(difficulty, kind),
        EnemyKind.hopper =>
          _justLanded &&
              distance >= 90 &&
              distance <= GameConstants.enemySkillRangeFor(difficulty, kind),
        EnemyKind.bruiser =>
          distance >= 70 &&
              distance <= GameConstants.enemySkillRangeFor(difficulty, kind),
        EnemyKind.trapper =>
          distance >= 80 &&
              distance <= GameConstants.enemySkillRangeFor(difficulty, kind),
      };
      if (canUseSkill) {
        dir = dx >= 0 ? 1 : -1;
        _warningTimer = GameConstants.enemySkillWarningFor(difficulty, kind);
        onSkillCue?.call(position.clone(), kind);
        return;
      }
    }

    if (kind == EnemyKind.hopper && _justLanded) {
      _hopVy = -420;
      _justLanded = false;
    }
    final move =
        speed *
        (kind == EnemyKind.bruiser ? 0.72 : 1.0) *
        (_pouncing
            ? GameConstants.enemyPounceSpeedMultiplierFor(difficulty)
            : 1.0);
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
        _hopVy = 0;
        _justLanded = true;
        _pouncing = false;
      }
    }
  }

  Color get _bodyColor {
    switch (kind) {
      case EnemyKind.hopper:
        return const Color(0xFFFFB74D);
      case EnemyKind.bruiser:
        return const Color(0xFFE57373);
      case EnemyKind.trapper:
        return const Color(0xFF72CDB1);
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
    canvas.drawCircle(
      Offset(-8, -size.y * 0.55),
      5,
      Paint()..color = Colors.white,
    );
    canvas.drawCircle(
      Offset(8, -size.y * 0.55),
      5,
      Paint()..color = Colors.white,
    );
    canvas.drawCircle(
      Offset(-8, -size.y * 0.55),
      2.5,
      Paint()..color = MacaronColors.cocoa,
    );
    canvas.drawCircle(
      Offset(8, -size.y * 0.55),
      2.5,
      Paint()..color = MacaronColors.cocoa,
    );
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
    if (kind == EnemyKind.trapper) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(0, -size.y * 0.86),
          width: 15,
          height: 8,
        ),
        Paint()..color = const Color(0xFFB8F0D8),
      );
    }
    if (_warningTimer > 0) {
      final center = Offset(0, -size.y - 15);
      final badge = RRect.fromRectAndRadius(
        Rect.fromCenter(center: center, width: 24, height: 24),
        const Radius.circular(8),
      );
      canvas.drawRRect(badge, Paint()..color = Colors.white);
      canvas.drawRRect(
        badge,
        Paint()
          ..color = _bodyColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      final cuePaint = Paint()
        ..color = MacaronColors.cocoa
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      switch (kind) {
        case EnemyKind.walker:
          canvas.drawCircle(
            center + const Offset(5, 0),
            3,
            Paint()..color = _bodyColor,
          );
          for (var i = -1; i <= 1; i++) {
            canvas.drawLine(
              center + Offset(-7, i * 4.0),
              center + Offset(-3, i * 4.0),
              cuePaint,
            );
          }
        case EnemyKind.hopper:
          final arc = Path()
            ..moveTo(center.dx - 7, center.dy + 4)
            ..quadraticBezierTo(
              center.dx,
              center.dy - 8,
              center.dx + 7,
              center.dy + 4,
            );
          canvas.drawPath(arc, cuePaint);
          canvas.drawLine(
            center + const Offset(-8, 7),
            center + const Offset(8, 7),
            cuePaint,
          );
        case EnemyKind.bruiser:
          final arrow = Path()
            ..moveTo(center.dx - 7, center.dy - 5)
            ..lineTo(center.dx + 7, center.dy)
            ..lineTo(center.dx - 7, center.dy + 5);
          canvas.drawPath(arrow, cuePaint);
          canvas.drawLine(
            center + const Offset(-8, 9),
            center + const Offset(1, 9),
            cuePaint,
          );
        case EnemyKind.trapper:
          final trap = Path()
            ..moveTo(center.dx, center.dy - 7)
            ..lineTo(center.dx + 6, center.dy + 4)
            ..lineTo(center.dx - 6, center.dy + 4)
            ..close();
          canvas.drawPath(trap, cuePaint);
          canvas.drawLine(
            center + const Offset(-8, 8),
            center + const Offset(8, 8),
            cuePaint,
          );
      }
    }
    canvas.restore();
  }
}

/// 怪物发射的糖豆，碰到地形或玩家后消失
class EnemyCandyShot extends PositionComponent {
  EnemyCandyShot({
    required Vector2 position,
    required this.direction,
    required this.speed,
  }) : super(
         position: position,
         size: Vector2.all(24),
         anchor: Anchor.center,
         priority: 42,
       );

  final double direction;
  final double speed;
  double _life = 2.8;
  double _wobble = 0;
  bool spent = false;

  void consume() {
    if (spent) {
      return;
    }
    spent = true;
    removeFromParent();
  }

  @override
  void update(double dt) {
    if (spent) {
      return;
    }
    _life -= dt;
    _wobble += dt * 12;
    position.x += direction * speed * dt;
    position.y += math.sin(_wobble) * 16 * dt;
    if (_life <= 0) {
      consume();
    }
  }

  @override
  void render(Canvas canvas) {
    if (spent) {
      return;
    }
    final squash = 1 + math.sin(_wobble) * 0.1;
    canvas.save();
    canvas.translate(size.x / 2, size.y / 2);
    canvas.scale(squash, 1 / squash);
    canvas.drawCircle(Offset.zero, 9, Paint()..color = MacaronColors.rose);
    canvas.drawCircle(
      const Offset(-3, -4),
      3,
      Paint()..color = Colors.white.withValues(alpha: 0.9),
    );
    canvas.drawCircle(
      const Offset(5, 4),
      1.5,
      Paint()..color = Colors.white.withValues(alpha: 0.8),
    );
    canvas.restore();
  }
}

/// 陷阱怪留下的黏糖地面，踩中会短暂减速，可跳过或用冲刺穿过。
class StickyCandyPatch extends PositionComponent {
  StickyCandyPatch({required Vector2 position})
    : super(
        position: position,
        size: Vector2(112, 28),
        anchor: Anchor.bottomCenter,
        priority: 39,
      );

  double _armingTimer = 0.42;
  double _life = GameConstants.enemyTrapDuration;
  double _pulse = 0;
  bool spent = false;

  bool get armed => !spent && _armingTimer <= 0;

  Rect get hitbox => Rect.fromLTWH(
    position.x - size.x / 2 + 8,
    position.y - size.y + 6,
    size.x - 16,
    size.y - 7,
  );

  void consume() {
    if (spent) {
      return;
    }
    spent = true;
    removeFromParent();
  }

  @override
  void update(double dt) {
    if (spent) {
      return;
    }
    _pulse += dt * 7;
    _armingTimer = (_armingTimer - dt).clamp(0.0, 1.0);
    _life -= dt;
    if (_life <= 0) {
      consume();
    }
  }

  @override
  void render(Canvas canvas) {
    if (spent) {
      return;
    }
    final alpha = armed ? 0.82 : 0.38 + math.sin(_pulse * 5).abs() * 0.3;
    final puddle = RRect.fromRectAndRadius(
      Rect.fromLTWH(7, size.y - 20, size.x - 14, 15),
      const Radius.circular(10),
    );
    canvas.drawOval(
      Rect.fromLTWH(10, size.y - 8, size.x - 20, 7),
      Paint()..color = const Color(0xFF5F8E7A).withValues(alpha: 0.2),
    );
    canvas.drawRRect(
      puddle,
      Paint()..color = const Color(0xFF7AD9B8).withValues(alpha: alpha),
    );
    canvas.drawRRect(
      puddle,
      Paint()
        ..color = Colors.white.withValues(alpha: armed ? 0.55 : 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = armed ? 1.5 : 2,
    );
    for (var i = 0; i < 3; i++) {
      final x = 25.0 + i * 30;
      final bubbleY = size.y - 17 - math.sin(_pulse + i) * 2;
      canvas.drawCircle(
        Offset(x, bubbleY),
        i == 1 ? 2.5 : 1.8,
        Paint()..color = Colors.white.withValues(alpha: alpha),
      );
    }
  }
}

/// 跑酷关卡中的限时糖果发射器
class GunPickup extends PositionComponent {
  GunPickup({required Vector2 position})
    : super(
        position: position,
        size: Vector2.all(42),
        anchor: Anchor.center,
        priority: 48,
      );

  bool collected = false;
  double _bob = 0;

  @override
  void update(double dt) {
    _bob += dt * 4;
  }

  @override
  void render(Canvas canvas) {
    if (collected) {
      return;
    }
    final y = math.sin(_bob) * 3;
    canvas.drawCircle(
      Offset(size.x / 2, size.y / 2 + y),
      19,
      Paint()..color = Colors.white.withValues(alpha: 0.8),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(8, 14 + y, 25, 12),
        const Radius.circular(5),
      ),
      Paint()..color = MacaronColors.rose,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(25, 17 + y, 11, 6),
        const Radius.circular(3),
      ),
      Paint()..color = MacaronColors.cocoa,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(12, 24 + y, 7, 10),
        const Radius.circular(3),
      ),
      Paint()..color = MacaronColors.lemon,
    );
    canvas.drawCircle(Offset(14, 17 + y), 2, Paint()..color = Colors.white);
  }
}

/// 花园守线道具：拾取后召来短时自动攻击的豌豆伙伴。
class PeaSeed extends PositionComponent {
  PeaSeed({required Vector2 position})
    : super(
        position: position,
        size: Vector2.all(42),
        anchor: Anchor.center,
        priority: 48,
      );

  bool collected = false;
  double _bob = 0;

  @override
  void update(double dt) {
    _bob += dt * 3.8;
  }

  @override
  void render(Canvas canvas) {
    if (collected) {
      return;
    }
    final lift = math.sin(_bob) * 3;
    canvas.drawCircle(
      Offset(size.x / 2, size.y / 2 + lift),
      19,
      Paint()..color = Colors.white.withValues(alpha: 0.82),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(12, 25 + lift, 19, 10),
        const Radius.circular(4),
      ),
      Paint()..color = const Color(0xFFB57A66),
    );
    canvas.drawLine(
      Offset(21, 27 + lift),
      Offset(21, 14 + lift),
      Paint()
        ..color = const Color(0xFF4F9D68)
        ..strokeWidth = 3,
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(15, 17 + lift), width: 11, height: 6),
      Paint()..color = MacaronColors.mint,
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(27, 16 + lift), width: 11, height: 6),
      Paint()..color = const Color(0xFF76C893),
    );
    canvas.drawCircle(
      Offset(21, 11 + lift),
      5,
      Paint()..color = const Color(0xFF83D69B),
    );
    canvas.drawCircle(
      Offset(23, 10 + lift),
      1.2,
      Paint()..color = MacaronColors.cocoa,
    );
  }
}

/// 跑酷路段里的玩具小车，提供短时加速与一次碰撞保护
class VehiclePickup extends PositionComponent {
  VehiclePickup({required Vector2 position})
    : super(
        position: position,
        size: Vector2(48, 38),
        anchor: Anchor.center,
        priority: 48,
      );

  bool collected = false;
  double _bob = 0;

  @override
  void update(double dt) {
    _bob += dt * 3.5;
  }

  @override
  void render(Canvas canvas) {
    if (collected) {
      return;
    }
    final y = math.sin(_bob) * 2;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(5, 14 + y, 38, 15),
        const Radius.circular(7),
      ),
      Paint()..color = MacaronColors.mint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(13, 15 + y)
        ..lineTo(19, 7 + y)
        ..lineTo(31, 7 + y)
        ..lineTo(37, 15 + y)
        ..close(),
      Paint()..color = MacaronColors.sky,
    );
    canvas.drawCircle(
      Offset(14, 29 + y),
      5,
      Paint()..color = MacaronColors.cocoa,
    );
    canvas.drawCircle(
      Offset(34, 29 + y),
      5,
      Paint()..color = MacaronColors.cocoa,
    );
    canvas.drawCircle(Offset(14, 29 + y), 2, Paint()..color = Colors.white);
    canvas.drawCircle(Offset(34, 29 + y), 2, Paint()..color = Colors.white);
  }
}

/// 玩家和豌豆伙伴发射的糖豆
class PlayerCandyShot extends PositionComponent {
  PlayerCandyShot({
    required Vector2 position,
    required Vector2 direction,
    this.isPea = false,
    this.speed = 520,
  }) : direction = direction.clone()..normalize(),
       super(
         position: position,
         size: Vector2.all(isPea ? 20 : 18),
         anchor: Anchor.center,
         priority: 44,
       );

  final Vector2 direction;
  final bool isPea;
  final double speed;
  double _life = 1.4;
  double _wobble = 0;
  bool spent = false;

  void consume() {
    if (spent) {
      return;
    }
    spent = true;
    removeFromParent();
  }

  @override
  void update(double dt) {
    if (spent) {
      return;
    }
    _life -= dt;
    _wobble += dt * 13;
    position += direction * (speed * dt);
    if (_life <= 0) {
      consume();
    }
  }

  @override
  void render(Canvas canvas) {
    if (spent) {
      return;
    }
    final center = Offset(size.x / 2, size.y / 2);
    final color = isPea ? MacaronColors.mint : MacaronColors.lemon;
    canvas.drawCircle(
      center,
      size.x * (0.4 + math.sin(_wobble) * 0.025),
      Paint()..color = color,
    );
    canvas.drawCircle(
      center,
      size.x * 0.22,
      Paint()..color = isPea ? const Color(0xFF76C893) : MacaronColors.rose,
    );
    canvas.drawCircle(
      center + const Offset(-3, -4),
      2.5,
      Paint()..color = Colors.white.withValues(alpha: 0.9),
    );
  }
}

enum BossAttackPattern {
  slam,
  rush,
  volley,
  pounce,
  trap,
  doubleRush,
  slamVolley,
  trapVolley,
  longVolley;

  static BossAttackPattern forWorld(int worldIndex) =>
      values[worldIndex % values.length];
}

/// 世界 Boss（需多次踩踏，半血进入狂暴）
class MacaronBoss extends PositionComponent {
  MacaronBoss({
    required Vector2 position,
    required this.leftBound,
    required this.rightBound,
    required this.worldIndex,
    this.onShoot,
    this.onLayTrap,
    this.maxHp = 3,
  }) : hp = maxHp,
       _baseY = position.y,
       super(
         position: position,
         size: Vector2(86, 72),
         anchor: Anchor.bottomCenter,
         priority: 45,
       );

  final double leftBound;
  final double rightBound;
  final int worldIndex;
  final int maxHp;
  final double _baseY;
  final void Function(Vector2 at, double direction)? onShoot;
  final void Function(Vector2 at)? onLayTrap;
  int hp;
  double dir = -1;
  double _wobble = 0;
  double _flash = 0;
  double? targetX;
  double _attackCooldown = 1.2;
  double _warningTimer = 0;
  bool _projectileDamageUsed = false;
  double _rushTimer = 0;
  double _rushPause = 0;
  int _rushBursts = 0;
  double _attackDirection = 1;
  double _attackTargetX = 0;
  double _volleyTimer = 0;
  int _volleyShots = 0;
  double _vy = 0;
  bool dead = false;
  bool enraged = false;
  bool isSlamming = false;
  bool isPouncing = false;
  bool get isRushing => _rushTimer > 0;

  BossAttackPattern get attackPattern =>
      BossAttackPattern.forWorld(worldIndex);
  bool get isTelegraphing => _warningTimer > 0;
  bool get canReceiveProjectile => isTelegraphing && !_projectileDamageUsed;

  /// 踩踏一次返回是否刚进入狂暴
  bool stompHit() {
    if (dead) {
      return false;
    }
    if (isTelegraphing) {
      _projectileDamageUsed = true;
    }
    return _takeDamage();
  }

  /// 每次攻击预警只允许一发远程反击，避免花弹齐射瞬间跳过 Boss 阶段。
  bool tryProjectileHit() {
    if (dead || !isTelegraphing || _projectileDamageUsed) {
      return false;
    }
    _projectileDamageUsed = true;
    _takeDamage();
    return true;
  }

  bool _takeDamage() {
    hp--;
    _flash = 0.35;
    var justEnraged = false;
    if (!enraged && hp <= (maxHp / 2).ceil()) {
      enraged = true;
      justEnraged = true;
      _attackCooldown = 0.2;
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
    _wobble += dt * (isRushing ? 15 : enraged ? 8 : 5);
    if (_flash > 0) {
      _flash -= dt;
    }
    if (enraged) {
      _attackCooldown = (_attackCooldown - dt).clamp(0.0, 10.0);
      if (_warningTimer > 0) {
        _warningTimer = (_warningTimer - dt).clamp(0.0, 2.0);
        if (_warningTimer <= 0) {
          _beginAttack();
        } else {
          return;
        }
      } else if (_attackCooldown <= 0 &&
          !isSlamming &&
          !isPouncing &&
          !isRushing &&
          _rushPause <= 0 &&
          _rushBursts == 0 &&
          _volleyShots == 0) {
        _attackTargetX = (targetX ?? position.x)
            .clamp(leftBound, rightBound)
            .toDouble();
        _attackDirection = _directionToTarget(_attackTargetX);
        dir = _attackDirection;
        _warningTimer = switch (attackPattern) {
          BossAttackPattern.trap || BossAttackPattern.trapVolley => 1.0,
          BossAttackPattern.pounce || BossAttackPattern.doubleRush => 0.9,
          BossAttackPattern.slamVolley => 0.88,
          _ => 0.78,
        };
        _projectileDamageUsed = false;
        return;
      }

      if (_rushPause > 0) {
        _rushPause = (_rushPause - dt).clamp(0.0, 1.0);
        if (_rushPause <= 0 && _rushBursts > 0) {
          _attackDirection = -_attackDirection;
          dir = _attackDirection;
          _rushTimer = 0.42;
        }
        return;
      }

      if (isRushing) {
        _rushTimer = (_rushTimer - dt).clamp(0.0, 1.0);
        position.x += _attackDirection * 390 * dt;
        if (position.x <= leftBound || position.x >= rightBound) {
          position.x = position.x.clamp(leftBound, rightBound);
          _rushTimer = 0;
          _rushBursts = 0;
          _rushPause = 0;
        } else if (_rushTimer <= 0) {
          _rushBursts--;
          if (_rushBursts > 0) {
            _rushPause = 0.3;
          }
        }
        return;
      }

      if (_volleyShots > 0) {
        _volleyTimer -= dt;
        if (_volleyTimer <= 0) {
          onShoot?.call(
            position + Vector2(_attackDirection * size.x * 0.55, -size.y * 0.58),
            _attackDirection,
          );
          _volleyShots--;
          _volleyTimer = 0.28;
        }
      }

      if (isPouncing) {
        _vy += 2200 * dt;
        position.x = (position.x + _attackDirection * 230 * dt)
            .clamp(leftBound, rightBound)
            .toDouble();
        position.y += _vy * dt;
        if (position.y >= _baseY) {
          position.y = _baseY;
          _vy = 0;
          isPouncing = false;
        }
        return;
      }
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

    if (enraged && isSlamming) {
      _vy += 2400 * dt;
      position.y += _vy * dt;
      if (position.y >= _baseY) {
        position.y = _baseY;
        _vy = 0;
        isSlamming = false;
      }
    } else if (!enraged) {
      position.y = _baseY;
    }
  }

  double _directionToTarget([double? snapshot]) {
    final target = snapshot ?? targetX;
    if (target == null || target == position.x) {
      return dir;
    }
    return target > position.x ? 1 : -1;
  }

  void _beginAttack() {
    switch (attackPattern) {
      case BossAttackPattern.slam:
        isSlamming = true;
        _vy = -780;
        _attackCooldown = 2.6;
      case BossAttackPattern.rush:
        _rushTimer = 0.68;
        _rushBursts = 1;
        _attackCooldown = 3.1;
      case BossAttackPattern.volley:
        _startVolley(3, 0.28);
        _attackCooldown = 3.3;
      case BossAttackPattern.pounce:
        isPouncing = true;
        _vy = -680;
        _attackCooldown = 3.4;
      case BossAttackPattern.trap:
        onLayTrap?.call(Vector2(_attackTargetX, _baseY));
        _attackCooldown = 4.0;
      case BossAttackPattern.doubleRush:
        _rushTimer = 0.42;
        _rushBursts = 2;
        _attackCooldown = 4.3;
      case BossAttackPattern.slamVolley:
        isSlamming = true;
        _vy = -780;
        _startVolley(3, 0.28);
        _attackCooldown = 3.8;
      case BossAttackPattern.trapVolley:
        onLayTrap?.call(Vector2(_attackTargetX, _baseY));
        _startVolley(2, 0.34);
        _attackCooldown = 4.5;
      case BossAttackPattern.longVolley:
        _startVolley(5, 0.3);
        _attackCooldown = 4.4;
    }
  }

  void _startVolley(int shots, double interval) {
    _volleyShots = shots;
    _volleyTimer = interval;
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
    canvas.drawCircle(
      Offset(-14, -size.y * 0.55),
      8,
      Paint()..color = Colors.white,
    );
    canvas.drawCircle(
      Offset(14, -size.y * 0.55),
      8,
      Paint()..color = Colors.white,
    );
    canvas.drawCircle(
      Offset(-14, -size.y * 0.55),
      4,
      Paint()..color = MacaronColors.cocoa,
    );
    canvas.drawCircle(
      Offset(14, -size.y * 0.55),
      4,
      Paint()..color = MacaronColors.cocoa,
    );
    canvas.drawCircle(
      Offset(0, -size.y * 0.78),
      10,
      Paint()..color = enraged ? const Color(0xFFFF5252) : MacaronColors.lemon,
    );
    if (isRushing) {
      final trailPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.75)
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;
      for (var i = 0; i < 3; i++) {
        final y = -size.y * (0.35 + i * 0.16);
        canvas.drawLine(
          Offset(-(size.x * 0.4 + i * 7), y),
          Offset(-(size.x * 0.66 + i * 7), y),
          trailPaint,
        );
      }
    }
    if (_warningTimer > 0) {
      final center = Offset(0, -size.y - 25);
      final badge = RRect.fromRectAndRadius(
        Rect.fromCenter(center: center, width: 48, height: 30),
        const Radius.circular(9),
      );
      canvas.drawRRect(
        badge,
        Paint()..color = Colors.white.withValues(alpha: 0.95),
      );
      canvas.drawRRect(
        badge,
        Paint()
          ..color = MacaronColors.rose
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      final cuePaint = Paint()
        ..color = MacaronColors.cocoa
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      switch (attackPattern) {
        case BossAttackPattern.slam:
          _drawSlamCue(canvas, center, cuePaint);
        case BossAttackPattern.rush:
          _drawRushCue(canvas, center, cuePaint);
        case BossAttackPattern.volley:
          _drawVolleyCue(canvas, center, cuePaint, 3);
        case BossAttackPattern.pounce:
          final arc = Path()
            ..moveTo(center.dx - 8, center.dy + 4)
            ..quadraticBezierTo(
              center.dx,
              center.dy - 10,
              center.dx + 8,
              center.dy + 4,
            );
          canvas.drawPath(arc, cuePaint);
          canvas.drawCircle(center + const Offset(0, 6), 2, cuePaint);
        case BossAttackPattern.trap:
          _drawTrapCue(canvas, center, cuePaint);
        case BossAttackPattern.doubleRush:
          _drawRushCue(canvas, center, cuePaint);
          canvas.drawLine(
            center + const Offset(-8, 10),
            center + const Offset(8, 10),
            cuePaint,
          );
        case BossAttackPattern.slamVolley:
          _drawSlamCue(canvas, center + const Offset(-9, 0), cuePaint);
          _drawVolleyCue(canvas, center + const Offset(9, 0), cuePaint, 3);
        case BossAttackPattern.trapVolley:
          _drawTrapCue(canvas, center + const Offset(-9, 0), cuePaint);
          _drawVolleyCue(canvas, center + const Offset(9, 0), cuePaint, 2);
        case BossAttackPattern.longVolley:
          _drawVolleyCue(canvas, center, cuePaint, 5);
      }
    }
    for (var i = 0; i < maxHp; i++) {
      canvas.drawCircle(
        Offset(-18 + i * 18.0, -size.y - 8),
        5,
        Paint()
          ..color = i < hp
              ? MacaronColors.rose
              : Colors.white.withValues(alpha: 0.35),
      );
    }
    canvas.restore();
  }

  void _drawSlamCue(Canvas canvas, Offset center, Paint paint) {
    canvas.drawLine(
      center + const Offset(0, -7),
      center + const Offset(0, 3),
      paint,
    );
    canvas.drawCircle(center + const Offset(0, 8), 1.5, paint);
  }

  void _drawRushCue(Canvas canvas, Offset center, Paint paint) {
    final arrow = Path()
      ..moveTo(center.dx - 7, center.dy - 5)
      ..lineTo(center.dx + 7, center.dy)
      ..lineTo(center.dx - 7, center.dy + 5);
    canvas.drawPath(arrow, paint);
  }

  void _drawVolleyCue(Canvas canvas, Offset center, Paint paint, int count) {
    final spacing = count == 5 ? 5.0 : 6.0;
    for (var i = 0; i < count; i++) {
      canvas.drawCircle(
        center + Offset((i - (count - 1) / 2) * spacing, 0),
        2,
        paint,
      );
    }
  }

  void _drawTrapCue(Canvas canvas, Offset center, Paint paint) {
    final trap = Path()
      ..moveTo(center.dx, center.dy - 7)
      ..lineTo(center.dx + 7, center.dy + 5)
      ..lineTo(center.dx - 7, center.dy + 5)
      ..close();
    canvas.drawPath(trap, paint);
    canvas.drawLine(
      center + const Offset(-9, 8),
      center + const Offset(9, 8),
      paint,
    );
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
