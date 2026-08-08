import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:macaron_girlfriend_run/data/game_models.dart';
import 'package:macaron_girlfriend_run/theme/macaron_colors.dart';

/// 甜妹平台跳跃主角
class GirlfriendPlayer extends PositionComponent {
  GirlfriendPlayer({required this.role, this.cosmeticId = 'classic'})
      : super(
          size: Vector2(standWidth, standHeight),
          anchor: Anchor.bottomCenter,
          priority: 100,
        );

  static const double standWidth = 52;
  static const double standHeight = 68;
  static const double duckHeight = 40;

  PlayerRole role;
  String cosmeticId;
  Vector2 velocity = Vector2.zero();
  bool onGround = false;
  bool facingRight = true;
  double coyoteTimer = 0;
  double jumpBufferTimer = 0;
  bool wantsLeft = false;
  bool wantsRight = false;
  bool wantsRun = false;
  bool wantsJump = false;
  bool ducking = false;

  int coins = 0;
  bool reachedGoal = false;
  bool dead = false;
  bool poweredUp = false;
  double invincibleTimer = 0;

  double _anim = 0;

  bool get isInvincible => invincibleTimer > 0;

  /// 碰撞用身高（下蹲时变矮）
  double get hitHeight => ducking ? duckHeight : standHeight;

  void resetInput() {
    wantsLeft = false;
    wantsRight = false;
    wantsRun = false;
    wantsJump = false;
  }

  void applyInput({
    required bool left,
    required bool right,
    required bool run,
    required bool jumpPressed,
  }) {
    wantsLeft = left;
    wantsRight = right;
    wantsRun = run;
    if (jumpPressed) {
      jumpBufferTimer = GameConstants.jumpBuffer;
    }
  }

  /// 切换下蹲姿态并同步碰撞盒高度
  void applyDuck(bool wantDuck) {
    final next = wantDuck && !dead && (onGround || coyoteTimer > 0.05);
    if (next == ducking) {
      if (next) {
        size = Vector2(standWidth, duckHeight);
      }
      return;
    }
    ducking = next;
    size = Vector2(standWidth, ducking ? duckHeight : standHeight);
  }

  void hurtFlash() {
    invincibleTimer = GameConstants.invincibleDuration;
  }

  void grantPower() {
    poweredUp = true;
  }

  void kill() {
    dead = true;
    ducking = false;
    size = Vector2(standWidth, standHeight);
    velocity.y = GameConstants.jumpVelocity * 0.6;
  }

  void reviveAt(Vector2 pos) {
    dead = false;
    ducking = false;
    size = Vector2(standWidth, standHeight);
    position.setFrom(pos);
    velocity.setZero();
    poweredUp = false;
    invincibleTimer = GameConstants.invincibleDuration;
  }

  @override
  void update(double dt) {
    _anim += dt * (velocity.x.abs() > 10 ? 14 : 4);
    if (invincibleTimer > 0) {
      invincibleTimer -= dt;
    }
  }

  @override
  void render(Canvas canvas) {
    if (isInvincible && (invincibleTimer * 12).floor().isOdd) {
      return;
    }
    final dress = role == PlayerRole.girlfriend
        ? (poweredUp ? MacaronColors.lilac : MacaronColors.blush)
        : MacaronColors.sky;
    final accent = role == PlayerRole.girlfriend
        ? MacaronColors.rose
        : const Color(0xFF5B8DEF);

    final squash = ducking ? 1.12 : (onGround ? 1.0 : 0.92);
    final stretch = ducking ? 0.72 : (onGround ? 1.0 : 1.08);
    final legSwing =
        ducking ? 0.0 : math.sin(_anim) * (velocity.x.abs() > 10 ? 6.0 : 1.5);

    canvas.save();
    canvas.translate(size.x / 2, size.y);
    canvas.scale(facingRight ? 1.0 : -1.0, 1.0);
    canvas.scale(squash, stretch);

    canvas.drawOval(
      Rect.fromCenter(center: const Offset(0, 2), width: 38, height: 10),
      Paint()..color = Colors.black.withValues(alpha: 0.18),
    );

    final legPaint = Paint()..color = const Color(0xFFFFE0D0);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(-8, -10 + legSwing),
          width: 10,
          height: ducking ? 10 : 18,
        ),
        const Radius.circular(4),
      ),
      legPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(8, -10 - legSwing),
          width: 10,
          height: ducking ? 10 : 18,
        ),
        const Radius.circular(4),
      ),
      legPaint,
    );

    final body = Path()
      ..moveTo(0, -size.y * 0.42)
      ..lineTo(-size.x * 0.42, -4)
      ..lineTo(size.x * 0.42, -4)
      ..close();
    canvas.drawPath(body, Paint()..color = dress);
    canvas.drawPath(
      body,
      Paint()
        ..color = accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(0, -size.y * 0.52),
          width: 26,
          height: 22,
        ),
        const Radius.circular(8),
      ),
      Paint()..color = dress,
    );

    canvas.drawCircle(
      Offset(0, -size.y * 0.72),
      16,
      Paint()..color = const Color(0xFFFFE0D0),
    );

    final hair = Path()
      ..moveTo(-14, -size.y * 0.72)
      ..quadraticBezierTo(0, -size.y * 0.92, 14, -size.y * 0.72)
      ..lineTo(12, -size.y * 0.62)
      ..lineTo(-12, -size.y * 0.62)
      ..close();
    canvas.drawPath(hair, Paint()..color = accent);

    canvas.drawCircle(
      Offset(0, -size.y * 0.82),
      5,
      Paint()..color = MacaronColors.lemon,
    );

    canvas.drawCircle(
      Offset(-5, -size.y * 0.74),
      3,
      Paint()..color = MacaronColors.cocoa,
    );
    canvas.drawCircle(
      Offset(5, -size.y * 0.74),
      3,
      Paint()..color = MacaronColors.cocoa,
    );
    canvas.drawCircle(
      Offset(-4, -size.y * 0.75),
      1.2,
      Paint()..color = Colors.white,
    );
    canvas.drawCircle(
      Offset(6, -size.y * 0.75),
      1.2,
      Paint()..color = Colors.white,
    );

    canvas.drawCircle(
      Offset(-10, -size.y * 0.68),
      3,
      Paint()..color = MacaronColors.rose.withValues(alpha: 0.45),
    );
    canvas.drawCircle(
      Offset(10, -size.y * 0.68),
      3,
      Paint()..color = MacaronColors.rose.withValues(alpha: 0.45),
    );

    _drawCosmetic(canvas);

    canvas.restore();
  }

  void _drawCosmetic(Canvas canvas) {
    switch (cosmeticId) {
      case 'ribbon':
        canvas.drawCircle(
          Offset(-8, -size.y * 0.92),
          5,
          Paint()..color = MacaronColors.rose,
        );
        canvas.drawCircle(
          Offset(8, -size.y * 0.92),
          5,
          Paint()..color = MacaronColors.rose,
        );
        break;
      case 'mint_trail':
        canvas.drawCircle(
          Offset(-14, -6),
          5,
          Paint()..color = MacaronColors.mint.withValues(alpha: 0.45),
        );
        break;
      case 'crown':
        canvas.drawPath(
          Path()
            ..moveTo(-10, -size.y * 0.9)
            ..lineTo(-6, -size.y * 1.02)
            ..lineTo(0, -size.y * 0.92)
            ..lineTo(6, -size.y * 1.02)
            ..lineTo(10, -size.y * 0.9)
            ..close(),
          Paint()..color = MacaronColors.lemon,
        );
        canvas.drawCircle(
          Offset(0, -size.y * 1.0),
          2.5,
          Paint()..color = Colors.white.withValues(alpha: 0.85),
        );
        break;
      case 'lilac_glow':
        canvas.drawCircle(
          Offset(0, -size.y * 0.45),
          34 + math.sin(_anim) * 2,
          Paint()..color = MacaronColors.lilac.withValues(alpha: 0.2),
        );
        break;
      case 'sparkle_shoes':
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: const Offset(-8, -2), width: 12, height: 7),
            const Radius.circular(3),
          ),
          Paint()..color = MacaronColors.lemon,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: const Offset(8, -2), width: 12, height: 7),
            const Radius.circular(3),
          ),
          Paint()..color = MacaronColors.lemon,
        );
        break;
      case 'strawberry_cape':
        canvas.drawPath(
          Path()
            ..moveTo(0, -size.y * 0.55)
            ..quadraticBezierTo(-28, -size.y * 0.2, -22, 4)
            ..quadraticBezierTo(-8, -size.y * 0.15, 0, -size.y * 0.35)
            ..close(),
          Paint()..color = MacaronColors.rose.withValues(alpha: 0.75),
        );
        break;
      default:
        break;
    }
  }
}
