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
  bool skillDashing = false;
  bool isDriving = false;
  bool holdingCandyGun = false;
  bool plantBuddyActive = false;
  double invincibleTimer = 0;

  bool get hasPlantBuddy => plantBuddyActive || cosmeticId == 'pea_buddy';

  double _anim = 0;
  double _moodClock = 0;
  bool _eyesClosed = false;

  bool get isInvincible => invincibleTimer > 0 || skillDashing;

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
    skillDashing = false;
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
    skillDashing = false;
    isDriving = false;
    holdingCandyGun = false;
    plantBuddyActive = false;
    invincibleTimer = GameConstants.invincibleDuration;
  }

  @override
  void update(double dt) {
    _anim += dt * (velocity.x.abs() > 10 ? 14 : 4);
    _moodClock += dt;
    final blinkPhase = _moodClock % 3.8;
    _eyesClosed = blinkPhase < 0.1 || (blinkPhase > 0.18 && blinkPhase < 0.27);
    if (invincibleTimer > 0) {
      invincibleTimer -= dt;
    }
  }

  @override
  void render(Canvas canvas) {
    if (invincibleTimer > 0 && (invincibleTimer * 12).floor().isOdd) {
      return;
    }
    final dress = role == PlayerRole.girlfriend
        ? (poweredUp ? MacaronColors.lilac : MacaronColors.blush)
        : MacaronColors.sky;
    final accent = role == PlayerRole.girlfriend
        ? MacaronColors.rose
        : const Color(0xFF5B8DEF);
    final hairColor = role == PlayerRole.girlfriend
        ? MacaronColors.rose
        : const Color(0xFF75536D);

    final squash = ducking ? 1.12 : (onGround ? 1.0 : 0.92);
    final stretch = ducking ? 0.72 : (onGround ? 1.0 : 1.08);
    final running = velocity.x.abs() > 10 && onGround && !ducking;
    final legSwing = ducking ? 0.0 : math.sin(_anim) * (running ? 7.0 : 1.5);
    final bodyBob = running ? math.sin(_anim * 0.5) * 1.1 : 0.0;
    final bodyLean = skillDashing ? 0.16 : (running ? 0.045 : 0.0);

    canvas.save();
    canvas.translate(size.x / 2, size.y);
    canvas.scale(facingRight ? 1.0 : -1.0, 1.0);
    canvas.scale(squash, stretch);
    canvas.translate(0, bodyBob);
    canvas.rotate(bodyLean);

    if (skillDashing) {
      final pulse = math.sin(_anim * 1.4) * 2;
      canvas.drawCircle(
        Offset(0, -size.y * 0.48),
        25 + pulse,
        Paint()
          ..color = MacaronColors.lemon.withValues(alpha: 0.62)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4,
      );
      for (var i = 0; i < 3; i++) {
        canvas.drawCircle(
          Offset(-25 - i * 8.0, -size.y * 0.36 + math.sin(_anim + i) * 4),
          3.5 - i * 0.5,
          Paint()
            ..color = (i.isEven ? MacaronColors.blush : Colors.white)
                .withValues(alpha: 0.75 - i * 0.16),
        );
      }
    }

    canvas.drawOval(
      Rect.fromCenter(center: const Offset(0, 2), width: 38, height: 10),
      Paint()..color = Colors.black.withValues(alpha: 0.18),
    );

    if (isDriving) {
      _drawVehicle(canvas);
    }

    canvas.save();
    canvas.scale(1.12, 1.08);
    final faceCenter = Offset(0, -size.y * 0.72);
    _drawHairBack(canvas, faceCenter, hairColor);
    _drawLegsAndShoes(canvas, legSwing, ducking);
    _drawArms(canvas, size.y, legSwing);
    _drawOutfit(canvas, dress, accent, size.y);
    _drawFace(canvas, faceCenter);
    _drawHairFront(canvas, faceCenter, hairColor);

    _drawCosmetic(canvas);
    if (plantBuddyActive && cosmeticId != 'pea_buddy') {
      _drawPeaBuddy(canvas);
    }
    if (holdingCandyGun) {
      _drawCandyGun(canvas);
    }

    canvas.restore();
    canvas.restore();
  }

  void _drawHairBack(Canvas canvas, Offset faceCenter, Color accent) {
    if (role == PlayerRole.boyfriend) {
      for (final side in [-1.0, 1.0]) {
        final sideburn = Path()
          ..moveTo(faceCenter.dx + side * 11, faceCenter.dy - 3)
          ..quadraticBezierTo(
            faceCenter.dx + side * 17,
            faceCenter.dy + 2,
            faceCenter.dx + side * 13,
            faceCenter.dy + 9,
          )
          ..lineTo(faceCenter.dx + side * 9, faceCenter.dy + 7)
          ..close();
        canvas.drawPath(
          sideburn,
          Paint()
            ..shader =
                LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color.lerp(accent, Colors.white, 0.15)!,
                    accent,
                    Color.lerp(accent, MacaronColors.cocoa, 0.25)!,
                  ],
                ).createShader(
                  Rect.fromLTWH(
                    faceCenter.dx + side * 18,
                    faceCenter.dy - 3,
                    9,
                    13,
                  ),
                ),
        );
      }
      return;
    }
    final sway = math.sin(_anim * 0.42) * 1.4;
    final hair = Path()
      ..moveTo(faceCenter.dx - 11, faceCenter.dy - 2)
      ..cubicTo(
        faceCenter.dx - 22,
        faceCenter.dy + 1,
        faceCenter.dx - 20 + sway,
        faceCenter.dy + 13,
        faceCenter.dx - 11 + sway,
        faceCenter.dy + 16,
      )
      ..cubicTo(
        faceCenter.dx - 5 + sway,
        faceCenter.dy + 10,
        faceCenter.dx - 8,
        faceCenter.dy + 5,
        faceCenter.dx - 3,
        faceCenter.dy + 1,
      )
      ..close();
    canvas.drawPath(
      hair,
      Paint()
        ..shader =
            LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.lerp(accent, Colors.white, 0.16)!,
                accent,
                Color.lerp(accent, MacaronColors.cocoa, 0.28)!,
              ],
            ).createShader(
              Rect.fromLTWH(faceCenter.dx - 23, faceCenter.dy - 2, 22, 20),
            ),
    );
    canvas.drawLine(
      Offset(faceCenter.dx - 16, faceCenter.dy + 3),
      Offset(faceCenter.dx - 12 + sway, faceCenter.dy + 12),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.3)
        ..strokeWidth = 1.2
        ..strokeCap = StrokeCap.round,
    );
    final sideLock = Path()
      ..moveTo(faceCenter.dx + 10, faceCenter.dy - 3)
      ..cubicTo(
        faceCenter.dx + 21,
        faceCenter.dy - 1,
        faceCenter.dx + 20 + sway,
        faceCenter.dy + 12,
        faceCenter.dx + 11 + sway,
        faceCenter.dy + 17,
      )
      ..cubicTo(
        faceCenter.dx + 6,
        faceCenter.dy + 12,
        faceCenter.dx + 8,
        faceCenter.dy + 5,
        faceCenter.dx + 10,
        faceCenter.dy - 3,
      )
      ..close();
    canvas.drawPath(
      sideLock,
      Paint()
        ..shader =
            LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [
                Color.lerp(accent, Colors.white, 0.2)!,
                accent,
                Color.lerp(accent, MacaronColors.cocoa, 0.25)!,
              ],
            ).createShader(
              Rect.fromLTWH(faceCenter.dx + 7, faceCenter.dy - 3, 16, 21),
            ),
    );
    canvas.drawLine(
      Offset(faceCenter.dx + 16, faceCenter.dy + 3),
      Offset(faceCenter.dx + 13 + sway, faceCenter.dy + 12),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.34)
        ..strokeWidth = 1.4
        ..strokeCap = StrokeCap.round,
    );
  }

  void _drawLegsAndShoes(Canvas canvas, double legSwing, bool ducking) {
    const skinShadow = Color(0xFFE9B9A8);
    const skin = Color(0xFFFFE4D6);
    final isBoyfriend = role == PlayerRole.boyfriend;
    final shoeColors = isBoyfriend
        ? const [Colors.white, Color(0xFFD8E5FF)]
        : const [Colors.white, Color(0xFFFFD8E4)];
    for (final side in [-1.0, 1.0]) {
      final swing = side < 0 ? legSwing : -legSwing;
      final leg = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(side * 8, -10 + swing),
          width: 9,
          height: ducking ? 10 : 18,
        ),
        const Radius.circular(4),
      );
      if (isBoyfriend) {
        canvas.drawRRect(
          leg.shift(const Offset(0.7, 1)),
          Paint()..color = MacaronColors.cocoa.withValues(alpha: 0.18),
        );
        canvas.drawRRect(
          leg,
          Paint()
            ..shader = const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF8CAFE4), Color(0xFF526FAD)],
            ).createShader(leg.outerRect),
        );
        canvas.drawLine(
          Offset(side * 8 - 2.4, -15 + swing),
          Offset(side * 8 - 2.4, -6 + swing),
          Paint()
            ..color = Colors.white.withValues(alpha: 0.44)
            ..strokeWidth = 0.9
            ..strokeCap = StrokeCap.round,
        );
      } else {
        canvas.drawRRect(leg, Paint()..color = skinShadow);
        canvas.drawRRect(
          leg.shift(const Offset(-1, -0.5)),
          Paint()..color = skin,
        );
      }

      final shoe = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(side * 8, -3.7 + swing * 0.25),
          width: 14,
          height: 7,
        ),
        const Radius.circular(3.5),
      );
      canvas.drawRRect(
        shoe.shift(const Offset(0, 1)),
        Paint()..color = MacaronColors.cocoa.withValues(alpha: 0.2),
      );
      canvas.drawRRect(
        shoe,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: shoeColors,
          ).createShader(shoe.outerRect),
      );
      canvas.drawLine(
        Offset(side * 8 - 4, -2.8 + swing * 0.25),
        Offset(side * 8 + 3, -2.8 + swing * 0.25),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.9)
          ..strokeWidth = 1.1
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  void _drawArms(Canvas canvas, double height, double legSwing) {
    final shoulderY = -height * 0.4;
    final handY = -height * 0.23;
    for (final side in [-1.0, 1.0]) {
      final shoulder = Offset(side * 9, shoulderY + 2);
      final armSwing = side < 0 ? -legSwing * 0.42 : legSwing * 0.42;
      final elbow = Offset(side * 13, shoulderY + 7 + armSwing * 0.35);
      final hand = Offset(side * 16, handY + armSwing);
      final arm = Path()
        ..moveTo(shoulder.dx, shoulder.dy)
        ..quadraticBezierTo(elbow.dx, elbow.dy, hand.dx, hand.dy);
      canvas.drawPath(
        arm.shift(const Offset(1, 1)),
        Paint()
          ..color = const Color(0xFFE8B1A2)
          ..strokeWidth = 6
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawPath(
        arm,
        Paint()
          ..color = const Color(0xFFFFE4D6)
          ..strokeWidth = 4.2
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawCircle(
        shoulder,
        4.2,
        Paint()..color = const Color(0xFFFFE4D6),
      );
      canvas.drawCircle(hand, 2.7, Paint()..color = const Color(0xFFFFE4D6));
    }
  }

  void _drawOutfit(Canvas canvas, Color outfit, Color accent, double height) {
    if (role == PlayerRole.boyfriend) {
      _drawBoyfriendOutfit(canvas, outfit, accent, height);
      return;
    }
    final shoulderY = -height * 0.43;
    final waistY = -height * 0.3;
    const hemY = -4.0;
    final skirt = Path()
      ..moveTo(-5, shoulderY)
      ..quadraticBezierTo(0, shoulderY - 3, 5, shoulderY)
      ..cubicTo(12, shoulderY + 2, 12, waistY - 3, 19, hemY - 1)
      ..quadraticBezierTo(0, hemY + 4, -19, hemY - 1)
      ..cubicTo(-12, waistY - 3, -12, shoulderY + 2, -5, shoulderY)
      ..close();
    final bounds = Rect.fromLTRB(-21, shoulderY - 3, 21, hemY + 4);
    canvas.drawPath(
      skirt.shift(const Offset(0, 2)),
      Paint()..color = MacaronColors.cocoa.withValues(alpha: 0.16),
    );
    canvas.drawPath(
      skirt,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(Colors.white, outfit, 0.18)!,
            outfit,
            Color.lerp(outfit, accent, 0.42)!,
          ],
        ).createShader(bounds),
    );
    canvas.drawPath(
      skirt,
      Paint()
        ..color = Color.lerp(
          accent,
          MacaronColors.cocoa,
          0.18,
        )!.withValues(alpha: 0.72)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.25,
    );
    for (final creaseX in [-11.0, -5.0, 5.0, 11.0]) {
      canvas.drawLine(
        Offset(creaseX * 0.52, waistY + 5),
        Offset(creaseX, hemY - 4),
        Paint()
          ..color = MacaronColors.cocoa.withValues(alpha: 0.18)
          ..strokeWidth = 0.85
          ..strokeCap = StrokeCap.round,
      );
    }
    final bodice = RRect.fromRectAndRadius(
      Rect.fromLTRB(-8, shoulderY + 1, 8, waistY + 4),
      const Radius.circular(4),
    );
    canvas.drawRRect(
      bodice,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.9),
            Color.lerp(outfit, Colors.white, 0.48)!,
          ],
        ).createShader(bodice.outerRect),
    );
    canvas.drawRRect(
      bodice,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1,
    );
    for (final side in [-1.0, 1.0]) {
      final sleeve = Rect.fromCenter(
        center: Offset(side * 10, shoulderY + 5),
        width: 11,
        height: 9,
      );
      canvas.drawOval(
        sleeve.shift(const Offset(0.8, 1.2)),
        Paint()..color = MacaronColors.cocoa.withValues(alpha: 0.12),
      );
      canvas.drawOval(
        sleeve,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white, Color(0xFFFFEDF2)],
          ).createShader(sleeve),
      );
      canvas.drawOval(
        sleeve,
        Paint()
          ..color = accent.withValues(alpha: 0.62)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.05,
      );
    }
    final neckline = Path()
      ..moveTo(-5, shoulderY + 3)
      ..quadraticBezierTo(0, shoulderY + 12, 5, shoulderY + 3);
    canvas.drawPath(
      neckline,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round,
    );
    for (final side in [-1.0, 1.0]) {
      canvas.drawLine(
        Offset(side * 3, shoulderY + 8),
        Offset(side * 8, hemY - 5),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.48)
          ..strokeWidth = 1.15
          ..strokeCap = StrokeCap.round,
      );
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(0, waistY + 2), width: 17, height: 3.5),
        const Radius.circular(2),
      ),
      Paint()..color = Color.lerp(accent, Colors.white, 0.42)!,
    );
    final bow = Path()
      ..moveTo(-1, waistY + 2)
      ..lineTo(-7, waistY - 2)
      ..lineTo(-6, waistY + 5)
      ..close();
    canvas.drawPath(bow, Paint()..color = accent);
    final otherBow = Path()
      ..moveTo(1, waistY + 2)
      ..lineTo(7, waistY - 2)
      ..lineTo(6, waistY + 5)
      ..close();
    canvas.drawPath(
      otherBow,
      Paint()..color = Color.lerp(accent, Colors.white, 0.24)!,
    );
    canvas.drawCircle(
      Offset(0, waistY + 2),
      2.5,
      Paint()..color = MacaronColors.lemon,
    );
    canvas.drawLine(
      Offset(-15, hemY - 1.3),
      Offset(15, hemY - 1.3),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.55)
        ..strokeWidth = 1.2
        ..strokeCap = StrokeCap.round,
    );
  }

  void _drawBoyfriendOutfit(
    Canvas canvas,
    Color jacket,
    Color accent,
    double height,
  ) {
    final shoulderY = -height * 0.43;
    final hemY = -13.0;
    final jacketShape = Path()
      ..moveTo(-6, shoulderY)
      ..quadraticBezierTo(-13, shoulderY + 2, -10, shoulderY + 11)
      ..lineTo(-12, hemY)
      ..quadraticBezierTo(0, hemY + 3, 12, hemY)
      ..lineTo(10, shoulderY + 11)
      ..quadraticBezierTo(13, shoulderY + 2, 6, shoulderY)
      ..close();
    canvas.drawPath(
      jacketShape.shift(const Offset(0, 2)),
      Paint()..color = MacaronColors.cocoa.withValues(alpha: 0.17),
    );
    canvas.drawPath(
      jacketShape,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(Colors.white, jacket, 0.3)!,
            jacket,
            Color.lerp(jacket, MacaronColors.cocoa, 0.16)!,
          ],
        ).createShader(Rect.fromLTRB(-13, shoulderY, 13, hemY + 3)),
    );
    canvas.drawPath(
      jacketShape,
      Paint()
        ..color = Color.lerp(accent, MacaronColors.cocoa, 0.28)!
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.15,
    );
    for (final side in [-1.0, 1.0]) {
      final sleeve = Rect.fromCenter(
        center: Offset(side * 10, shoulderY + 7),
        width: 10,
        height: 13,
      );
      canvas.drawOval(
        sleeve,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color.lerp(Colors.white, jacket, 0.18)!,
              Color.lerp(jacket, accent, 0.18)!,
            ],
          ).createShader(sleeve),
      );
      canvas.drawLine(
        Offset(side * 10 - 3, shoulderY + 12),
        Offset(side * 10 + 3, shoulderY + 12),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.62)
          ..strokeWidth = 1.1
          ..strokeCap = StrokeCap.round,
      );
    }
    final collar = Path()
      ..moveTo(-5, shoulderY + 2)
      ..lineTo(0, shoulderY + 9)
      ..lineTo(5, shoulderY + 2);
    canvas.drawPath(
      collar,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawLine(
      Offset(0, shoulderY + 9),
      Offset(0, hemY - 2),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.78)
        ..strokeWidth = 1.1,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(-9, hemY - 6, 7, 4),
        const Radius.circular(1.5),
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.48),
    );
    canvas.drawCircle(
      Offset(0, hemY - 7),
      1.1,
      Paint()..color = MacaronColors.lemon,
    );
  }

  void _drawFace(Canvas canvas, Offset center) {
    const skin = Color(0xFFFFE4D6);
    final face = Rect.fromCenter(center: center, width: 32, height: 34);
    canvas.drawOval(
      face.shift(const Offset(1.2, 1.8)),
      Paint()..color = const Color(0xFFB97772).withValues(alpha: 0.2),
    );
    for (final side in [-1.0, 1.0]) {
      canvas.drawOval(
        Rect.fromCenter(
          center: center.translate(side * 14.8, 1),
          width: 6.5,
          height: 8.5,
        ),
        Paint()..color = const Color(0xFFFFD4C4),
      );
    }
    canvas.drawOval(
      face,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFF4E9), skin, Color(0xFFFFD0C2)],
        ).createShader(face),
    );
    canvas.drawOval(
      face,
      Paint()
        ..color = const Color(0xFFC78C82).withValues(alpha: 0.42)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.9,
    );

    for (final side in [-1.0, 1.0]) {
      final eye = center.translate(side * 5.9, 1.1);
      if (_eyesClosed) {
        canvas.drawLine(
          eye.translate(-2.4, 0),
          eye.translate(2.4, 0),
          Paint()
            ..color = MacaronColors.cocoa
            ..strokeWidth = 1.8
            ..strokeCap = StrokeCap.round,
        );
      } else {
        final eyeWhite = Rect.fromCenter(center: eye, width: 6, height: 8);
        canvas.drawOval(eyeWhite, Paint()..color = Colors.white);
        canvas.drawOval(
          Rect.fromCenter(
            center: eye.translate(0.5, 0.7),
            width: 4,
            height: 5.8,
          ),
          Paint()..color = MacaronColors.cocoa,
        );
        canvas.drawCircle(
          eye.translate(-0.3, -0.8),
          1.25,
          Paint()..color = Colors.white,
        );
      }
      canvas.drawLine(
        center.translate(side * 7, -4.5),
        center.translate(side * 4.2, -5),
        Paint()
          ..color = const Color(0xFF9C6870).withValues(alpha: 0.72)
          ..strokeWidth = 1.35
          ..strokeCap = StrokeCap.round,
      );
      if (role == PlayerRole.girlfriend) {
        for (final lash in [-1.0, 1.0]) {
          canvas.drawLine(
            eye.translate(lash * 2.2, -3.1),
            eye.translate(lash * 2.8, -4.1),
            Paint()
              ..color = MacaronColors.cocoa.withValues(alpha: 0.72)
              ..strokeWidth = 0.9
              ..strokeCap = StrokeCap.round,
          );
        }
      }
    }
    canvas.drawCircle(
      center.translate(0, 4.2),
      0.9,
      Paint()..color = const Color(0xFFE4A49A),
    );
    final smile = Path()
      ..moveTo(center.dx - 3, center.dy + 8)
      ..quadraticBezierTo(
        center.dx,
        center.dy + 11,
        center.dx + 3,
        center.dy + 8,
      );
    canvas.drawPath(
      smile,
      Paint()
        ..color = const Color(0xFF9D6269)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.35
        ..strokeCap = StrokeCap.round,
    );
    for (final side in [-1.0, 1.0]) {
      canvas.drawOval(
        Rect.fromCenter(
          center: center.translate(side * 10, 5.4),
          width: 6.2,
          height: 3.8,
        ),
        Paint()..color = MacaronColors.rose.withValues(alpha: 0.34),
      );
      canvas.drawCircle(
        center.translate(side * 10 - 0.6, 5),
        0.75,
        Paint()..color = Colors.white.withValues(alpha: 0.6),
      );
    }
  }

  void _drawHairFront(Canvas canvas, Offset center, Color accent) {
    if (role == PlayerRole.boyfriend) {
      final shortCut = Path()
        ..moveTo(center.dx - 15, center.dy - 2)
        ..cubicTo(
          center.dx - 17,
          center.dy - 12,
          center.dx - 10,
          center.dy - 18,
          center.dx - 1,
          center.dy - 16,
        )
        ..cubicTo(
          center.dx + 8,
          center.dy - 20,
          center.dx + 17,
          center.dy - 12,
          center.dx + 15,
          center.dy - 2,
        )
        ..lineTo(center.dx + 8, center.dy - 7)
        ..lineTo(center.dx + 4, center.dy - 4)
        ..lineTo(center.dx, center.dy - 8)
        ..lineTo(center.dx - 5, center.dy - 4)
        ..lineTo(center.dx - 9, center.dy - 7)
        ..close();
      canvas.drawPath(
        shortCut,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.lerp(Colors.white, accent, 0.22)!,
              accent,
              Color.lerp(accent, MacaronColors.cocoa, 0.32)!,
            ],
          ).createShader(Rect.fromLTWH(center.dx - 17, center.dy - 20, 34, 20)),
      );
      canvas.drawPath(
        shortCut,
        Paint()
          ..color = MacaronColors.cocoa.withValues(alpha: 0.3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
      canvas.drawLine(
        center.translate(-8, -13),
        center.translate(-3, -15),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.52)
          ..strokeWidth = 1.25
          ..strokeCap = StrokeCap.round,
      );
      return;
    }
    final cap = Path()
      ..moveTo(center.dx - 14, center.dy - 1)
      ..cubicTo(
        center.dx - 16,
        center.dy - 13,
        center.dx - 9,
        center.dy - 17,
        center.dx,
        center.dy - 16,
      )
      ..cubicTo(
        center.dx + 10,
        center.dy - 17,
        center.dx + 16,
        center.dy - 10,
        center.dx + 14,
        center.dy - 2,
      )
      ..quadraticBezierTo(
        center.dx + 8,
        center.dy - 7,
        center.dx + 4,
        center.dy - 8,
      )
      ..quadraticBezierTo(
        center.dx,
        center.dy - 3,
        center.dx - 4,
        center.dy - 8,
      )
      ..quadraticBezierTo(
        center.dx - 9,
        center.dy - 4,
        center.dx - 14,
        center.dy - 1,
      )
      ..close();
    canvas.drawPath(
      cap,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(Colors.white, accent, 0.24)!,
            accent,
            Color.lerp(accent, MacaronColors.cocoa, 0.24)!,
          ],
        ).createShader(Rect.fromLTWH(center.dx - 16, center.dy - 18, 32, 18)),
    );
    canvas.drawPath(
      cap,
      Paint()
        ..color = MacaronColors.cocoa.withValues(alpha: 0.2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.9,
    );
    canvas.drawLine(
      center.translate(-8, -13),
      center.translate(-3, -15),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.48)
        ..strokeWidth = 1.2
        ..strokeCap = StrokeCap.round,
    );
    final clip = Path()
      ..moveTo(center.dx + 7, center.dy - 15)
      ..lineTo(center.dx + 9, center.dy - 12)
      ..lineTo(center.dx + 12, center.dy - 13)
      ..lineTo(center.dx + 10, center.dy - 10)
      ..lineTo(center.dx + 12, center.dy - 8)
      ..lineTo(center.dx + 8, center.dy - 9)
      ..lineTo(center.dx + 6, center.dy - 12)
      ..close();
    canvas.drawPath(clip, Paint()..color = MacaronColors.lemon);
    canvas.drawCircle(
      center.translate(8.8, -12.2),
      1.1,
      Paint()..color = Colors.white.withValues(alpha: 0.9),
    );
  }

  void _drawVehicle(Canvas canvas) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-35, -20, 70, 22),
        const Radius.circular(9),
      ),
      Paint()..color = MacaronColors.mint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(-23, -19)
        ..lineTo(-14, -30)
        ..lineTo(12, -30)
        ..lineTo(22, -19)
        ..close(),
      Paint()..color = MacaronColors.sky,
    );
    for (final x in [-21.0, 21.0]) {
      canvas.drawCircle(Offset(x, -1), 7, Paint()..color = MacaronColors.cocoa);
      canvas.drawCircle(Offset(x, -1), 3, Paint()..color = Colors.white);
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(27, -15, 6, 5),
        const Radius.circular(2),
      ),
      Paint()..color = MacaronColors.lemon,
    );
  }

  void _drawCandyGun(Canvas canvas) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(13, -size.y * 0.48, 23, 9),
        const Radius.circular(4),
      ),
      Paint()..color = MacaronColors.rose,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(17, -size.y * 0.48 + 6, 7, 9),
        const Radius.circular(3),
      ),
      Paint()..color = MacaronColors.lemon,
    );
    canvas.drawCircle(
      Offset(17, -size.y * 0.48 - 1),
      2,
      Paint()..color = Colors.white,
    );
  }

  void _drawPeaBuddy(Canvas canvas) {
    final bob = math.sin(_anim * 0.55) * 1.5;
    canvas.drawLine(
      Offset(-4, -size.y * 0.88),
      Offset(-2, -size.y * 1.02 + bob),
      Paint()
        ..color = const Color(0xFF55A86A)
        ..strokeWidth = 3,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(-8, -size.y * 0.96 + bob),
        width: 11,
        height: 5,
      ),
      Paint()..color = MacaronColors.mint,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(4, -size.y * 0.98 + bob),
        width: 11,
        height: 5,
      ),
      Paint()..color = const Color(0xFF76C893),
    );
    canvas.drawCircle(
      Offset(1, -size.y * 1.03 + bob),
      8,
      Paint()..color = const Color(0xFF83D69B),
    );
    canvas.drawCircle(
      Offset(7, -size.y * 1.03 + bob),
      4,
      Paint()..color = const Color(0xFF4EAA71),
    );
    canvas.drawCircle(
      Offset(8, -size.y * 1.03 + bob),
      1.5,
      Paint()..color = MacaronColors.cocoa,
    );
  }

  void _drawSunflowerBuddy(Canvas canvas) {
    const center = Offset(22, -30);
    canvas.drawLine(
      const Offset(16, -12),
      center,
      Paint()
        ..color = const Color(0xFF55A86A)
        ..strokeWidth = 3,
    );
    for (var i = 0; i < 8; i++) {
      final angle = i * math.pi / 4;
      canvas.drawCircle(
        center + Offset(math.cos(angle) * 7, math.sin(angle) * 7),
        3.5,
        Paint()..color = MacaronColors.lemon,
      );
    }
    canvas.drawCircle(center, 5, Paint()..color = const Color(0xFF9B6A45));
    canvas.drawCircle(
      const Offset(20, -31),
      1.2,
      Paint()..color = Colors.white,
    );
    canvas.drawOval(
      const Rect.fromLTWH(11, -17, 8, 4),
      Paint()..color = MacaronColors.mint,
    );
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
      case 'pea_buddy':
        _drawPeaBuddy(canvas);
        break;
      case 'sunflower_buddy':
        _drawSunflowerBuddy(canvas);
        break;
      default:
        break;
    }
  }
}
