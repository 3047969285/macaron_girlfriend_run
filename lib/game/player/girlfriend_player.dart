import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:macaron_girlfriend_run/data/game_models.dart';
import 'package:macaron_girlfriend_run/game/entities/entities.dart'
    show drawCarLabel;
import 'package:macaron_girlfriend_run/game/player/hero_sprites.dart';
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
  bool ducking = false;

  int coins = 0;
  bool reachedGoal = false;
  bool dead = false;
  bool poweredUp = false;
  bool skillDashing = false;
  bool pounding = false;
  bool isDriving = false;
  bool vehicleBoosting = false;
  bool holdingCandyGun = false;
  bool superMode = false;
  bool flying = false;
  bool gumBubble = false;
  bool plantBuddyActive = false;
  bool plantFacingRight = true;
  double invincibleTimer = 0;

  bool get hasPlantBuddy => plantBuddyActive || cosmeticId == 'pea_buddy';

  double _anim = 0;
  double _moodClock = 0;
  bool _eyesClosed = false;
  double _plantShotTimer = 0;
  double _wheelSpin = 0;

  void plantFired({required bool toRight}) {
    plantFacingRight = toRight;
    _plantShotTimer = 0.18;
  }

  bool get isInvincible => invincibleTimer > 0 || skillDashing;

  /// 碰撞用身高（下蹲时变矮）
  double get hitHeight => ducking ? duckHeight : standHeight;

  void resetInput() {
    wantsLeft = false;
    wantsRight = false;
    wantsRun = false;
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
    pounding = false;
    ducking = false;
    size = Vector2(standWidth, standHeight);
    velocity
      ..x = 0
      ..y = GameConstants.jumpVelocity * 0.6;
  }

  void reviveAt(Vector2 pos) {
    dead = false;
    ducking = false;
    size = Vector2(standWidth, standHeight);
    position.setFrom(pos);
    velocity.setZero();
    poweredUp = false;
    skillDashing = false;
    pounding = false;
    isDriving = false;
    vehicleBoosting = false;
    holdingCandyGun = false;
    superMode = false;
    flying = false;
    gumBubble = false;
    plantBuddyActive = false;
    plantFacingRight = facingRight;
    _plantShotTimer = 0;
    invincibleTimer = GameConstants.invincibleDuration;
  }

  /// 站在地面上时，物理每隔几帧会下沉约 3 像素再被顶回来，`onGround` 随之闪烁。
  /// 画面上这会表现成颤抖，所以只在显示层吸收：刚落地不久、没有起跳、下沉
  /// 不到 4.5 像素时，仍按站立姿态绘制，并把脚钉在落地高度。
  double _groundGrace = 0;
  double _lastGroundY = 0;

  bool get visuallyGrounded =>
      onGround ||
      (_groundGrace > 0 && velocity.y >= 0 && position.y - _lastGroundY < 4.5);

  /// 画面需要上提的距离（<= 0），抵消物理下沉。
  double get visualLift => (visuallyGrounded && !onGround)
      ? math.min(0, _lastGroundY - position.y)
      : 0;

  @override
  void update(double dt) {
    if (isDriving) {
      _wheelSpin = (_wheelSpin + velocity.x.abs() * dt / 7) % (math.pi * 2);
    }
    _plantShotTimer = math.max(0, _plantShotTimer - dt);
    if (onGround) {
      _groundGrace = 0.15;
      _lastGroundY = position.y;
    } else {
      _groundGrace = math.max(0, _groundGrace - dt);
    }
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
        ? (poweredUp ? MacaronColors.lilac : const Color(0xFFBBD7F0))
        : MacaronColors.sky;
    final accent = role == PlayerRole.girlfriend
        ? const Color(0xFFD77A96)
        : const Color(0xFF5B8DEF);
    final hairColor = role == PlayerRole.girlfriend
        ? const Color(0xFF7B2536)
        : const Color(0xFF75536D);

    final grounded = visuallyGrounded;
    final squash = pounding
        ? 0.78
        : ducking
        ? 1.12
        : (grounded ? 1.0 : 0.92);
    final stretch = pounding
        ? 1.28
        : ducking
        ? 0.72
        : (grounded ? 1.0 : 1.08);
    final running = velocity.x.abs() > 10 && grounded && !ducking;
    final falling = !grounded && velocity.y > 90 && !pounding && !skillDashing;
    final rising = !grounded && velocity.y < -90 && !pounding && !skillDashing;
    final legSwing = ducking
        ? 0.0
        : pounding
        ? 7.0
        : falling
        ? 5.0 + math.sin(_anim) * 1.5
        : rising
        ? -3.0
        : (running ? math.sin(_anim) * 4.0 : 0.0);
    // 待机时人物保持静止，只有眨眼；动作只在跑动、跳跃、下落时出现。
    final bodyBob = running
        ? math.sin(_anim * 2) * 2.4
        : falling
        ? 1.2
        : 0.0;
    const idleTilt = 0.0;
    final bodyLean = skillDashing
        ? 0.16
        : pounding
        ? 0.1
        : falling
        ? -0.11
        : rising
        ? 0.035
        : running
        ? 0.045
        : idleTilt;

    canvas.save();
    canvas.translate(size.x / 2, size.y + visualLift);
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

    if (superMode) {
      _drawCape(canvas);
    }
    if (flying) {
      _drawPlane(canvas);
    } else if (isDriving) {
      _drawVehicle(canvas);
    }

    if (role == PlayerRole.girlfriend && HeroSprites.ready) {
      _drawHeroSprite(
        canvas,
        running: running,
        falling: falling,
        rising: rising,
      );
      if (holdingCandyGun) {
        _drawCandyGun(canvas);
      }
      if (superMode) {
        // 眼睛发红光（头部在站立高度的约 92% 处）。
        for (final dx in const [-1.0, 4.0]) {
          canvas.drawCircle(
            Offset(dx + 3, -_spriteHeight * 0.915),
            3.0,
            Paint()
              ..color = const Color(0xFFFF4040).withValues(alpha: 0.75)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5),
          );
        }
      }
      canvas.restore();
      if (gumBubble) {
        _drawGumBubble(canvas);
      }
      canvas.restore();
      return;
    }

    canvas.save();
    canvas.scale(1.1, 1.1);
    final faceCenter = Offset(0, -size.y * 0.78);
    // 半写实比例：头缩小、躯干和手臂拉长（碰撞盒尺寸不变）。
    final bodyH = size.y * 1.3;
    _withHead(canvas, faceCenter, () {
      _drawHairBack(canvas, faceCenter, hairColor);
    });
    _drawLegsAndShoes(
      canvas,
      legSwing,
      ducking,
      running: running,
      airborne: falling || rising,
      pounding: pounding,
    );
    _drawArms(
      canvas,
      bodyH,
      legSwing,
      falling: falling,
      pounding: pounding,
      runPhase: running ? _anim : null,
    );
    _drawNeck(canvas, faceCenter, bodyH);
    _drawOutfit(
      canvas,
      dress,
      accent,
      bodyH,
      hemSwing: pounding
          ? 3.0
          : falling
          ? -4.0
          : (running ? math.sin(_anim) * 5.0 : 0.0),
    );
    _withHead(canvas, faceCenter, () {
      _drawFace(canvas, faceCenter);
      _drawHairFront(canvas, faceCenter, hairColor);
      _drawCosmetic(canvas);
    });
    if (plantBuddyActive && cosmeticId != 'pea_buddy') {
      _drawPeaBuddy(canvas);
    }
    if (holdingCandyGun) {
      _drawCandyGun(canvas);
    }
    if (superMode) {
      // 眼睛发红光。
      for (final dx in const [-3.2, 3.2]) {
        canvas.drawCircle(
          Offset(dx + 4, faceCenter.dy - 1),
          3.2,
          Paint()
            ..color = const Color(0xFFFF4040).withValues(alpha: 0.75)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5),
        );
      }
    }

    canvas.restore();
    if (gumBubble) {
      canvas.drawCircle(
        Offset(0, -size.y * 0.55),
        size.y * 0.78,
        Paint()..color = MacaronColors.blush.withValues(alpha: 0.28),
      );
      canvas.drawCircle(
        Offset(0, -size.y * 0.55),
        size.y * 0.78,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.7)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
    canvas.restore();
  }

  /// 立绘里站立的人物在屏幕上的高度（含头发）。
  double get _spriteHeight => size.y * 1.62;

  void _drawHeroSprite(
    Canvas canvas, {
    required bool running,
    required bool falling,
    required bool rising,
  }) {
    final HeroPose pose;
    if (ducking) {
      pose = HeroPose.duck;
    } else if (pounding || falling) {
      pose = HeroPose.fall;
    } else if (rising) {
      pose = HeroPose.jump;
    } else if (running) {
      // 跑步循环：四帧依次播放，速度跟着 _anim 走。
      const cycle = [
        HeroPose.run1,
        HeroPose.run2,
        HeroPose.run3,
        HeroPose.run4,
      ];
      pose = cycle[((_anim * 0.55).floor() % 4 + 4) % 4];
    } else {
      pose = HeroPose.stand;
    }
    HeroSprites.draw(canvas, pose, _spriteHeight);
  }

  void _drawGumBubble(Canvas canvas) {
    canvas.drawCircle(
      Offset(0, -size.y * 0.55),
      size.y * 0.78,
      Paint()..color = MacaronColors.blush.withValues(alpha: 0.28),
    );
    canvas.drawCircle(
      Offset(0, -size.y * 0.55),
      size.y * 0.78,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  void _drawCape(Canvas canvas) {
    final flap = math.sin(_anim * 0.9) * 4;
    canvas.drawPath(
      Path()
        ..moveTo(-4, -size.y * 0.88)
        ..quadraticBezierTo(
          -26,
          -size.y * 0.6 + flap,
          -34,
          -size.y * 0.18 + flap,
        )
        ..lineTo(-6, -size.y * 0.3)
        ..close(),
      Paint()..color = const Color(0xFFE8484F),
    );
  }

  void _drawPlane(Canvas canvas) {
    final y = math.sin(_anim * 0.5) * 1.5;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(-42, -22 + y, 84, 16),
        const Radius.circular(8),
      ),
      Paint()..color = const Color(0xFFF2F4F7),
    );
    canvas.drawPath(
      Path()
        ..moveTo(36, -22 + y)
        ..lineTo(54, -14 + y)
        ..lineTo(36, -6 + y)
        ..close(),
      Paint()..color = MacaronColors.rose,
    );
    canvas.drawPath(
      Path()
        ..moveTo(-42, -20 + y)
        ..lineTo(-52, -34 + y)
        ..lineTo(-30, -20 + y)
        ..close(),
      Paint()..color = MacaronColors.rose,
    );
    canvas.drawPath(
      Path()
        ..moveTo(-8, -8 + y)
        ..lineTo(-22, 8 + y)
        ..lineTo(6, -6 + y)
        ..close(),
      Paint()..color = MacaronColors.sky,
    );
    canvas.drawCircle(
      Offset(-46 - _wheelSpin.abs() % 3, -14 + y),
      3,
      Paint()..color = MacaronColors.lemon.withValues(alpha: 0.8),
    );
  }

  /// 头部整体缩小到 80%，以脸中心为基准，身体比例更接近真人。
  static const double _headScale = 0.68;

  void _withHead(Canvas canvas, Offset center, VoidCallback draw) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(_headScale);
    canvas.translate(-center.dx, -center.dy);
    draw();
    canvas.restore();
  }

  void _drawNeck(Canvas canvas, Offset faceCenter, double bodyH) {
    final top = faceCenter.dy + 9;
    final bottom = -bodyH * 0.43 + 4;
    final neck = RRect.fromRectAndRadius(
      Rect.fromLTRB(-3.2, top, 3.2, bottom),
      const Radius.circular(2.5),
    );
    canvas.drawRRect(
      neck,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFE9B9A8), Color(0xFFFFE4D6)],
        ).createShader(neck.outerRect),
    );
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
    _drawLongHairBack(canvas, faceCenter, accent);
  }

  /// 腿部骨架：髋 → 膝 → 踝两段，按姿态/跑步相位摆动，脚随小腿转。
  /// 朝向 +x（向右），整个人物水平翻转时一起翻转。
  void _drawLegsAndShoes(
    Canvas canvas,
    double legSwing,
    bool ducking, {
    bool running = false,
    bool airborne = false,
    bool pounding = false,
  }) {
    const skinShadow = Color(0xFFE9B9A8);
    const skin = Color(0xFFFFE4D6);
    final isBoyfriend = role == PlayerRole.boyfriend;
    const hipY = -19.0;
    const thigh = 6.5;
    const shin = 6.5;
    const hipX = 4.2;
    const groundAnkleY = -6.0;

    // 每条腿的（大腿角度，膝盖弯曲）；角度以向下为 0，向前（+x）为正。
    (double, double) pose(double side) {
      if (ducking) {
        return (0.95, 1.55);
      }
      if (pounding) {
        return (0.08 * side, 0.0);
      }
      if (running) {
        final phase = _anim + (side < 0 ? 0 : math.pi);
        // 前摆的腿（sin 上升）在身体下方收膝，后蹬的腿伸直。
        final swing = math.sin(phase);
        final lift = math.max(0.0, math.cos(phase));
        return (0.78 * swing, 0.12 + 1.0 * lift);
      }
      if (airborne) {
        // 上升：一条腿屈膝收起；下落：双腿分开准备落地。
        if (velocity.y < 0) {
          return side < 0 ? (0.55, 1.0) : (-0.18, 0.45);
        }
        return (0.3 * side, 0.18);
      }
      return (0.0, 0.0);
    }

    final legs =
        <
          (double side, Offset hip, Offset knee, Offset ankle, double shinAngle)
        >[];
    var lowest = -1000.0;
    for (final side in [-1.0, 1.0]) {
      final (thighAngle, bend) = pose(side);
      final hip = Offset(side * hipX, hipY);
      final knee =
          hip + Offset(math.sin(thighAngle), math.cos(thighAngle)) * thigh;
      final shinAngle = thighAngle - bend;
      final ankle =
          knee + Offset(math.sin(shinAngle), math.cos(shinAngle)) * shin;
      legs.add((side, hip, knee, ankle, shinAngle));
      lowest = math.max(lowest, ankle.dy);
    }
    // 让落地的那只脚踩在地面上（只下压，最多 4 像素；腾空时不下压）。
    final onFloor = !airborne && !pounding;
    final drop = onFloor ? (groundAnkleY - lowest).clamp(0.0, 4.0) : 0.0;

    final shoeColors = isBoyfriend
        ? const [Colors.white, Color(0xFFD8E5FF)]
        : const [Colors.white, Color(0xFFFFD8E4)];

    // 远侧的腿（side = -1 先画）在下，近侧的腿盖在上面。
    for (final (_, hip, knee, ankle, shinAngle) in legs) {
      final top = Offset(hip.dx, hip.dy - 3 + drop);
      final k = knee.translate(0, drop);
      final a = ankle.translate(0, drop);
      final path = Path()
        ..moveTo(top.dx, top.dy)
        ..lineTo(k.dx, k.dy)
        ..lineTo(a.dx, a.dy);
      final legPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      if (isBoyfriend) {
        canvas.drawPath(
          path.shift(const Offset(0.8, 1)),
          legPaint
            ..color = MacaronColors.cocoa.withValues(alpha: 0.18)
            ..strokeWidth = 7.2,
        );
        canvas.drawPath(
          path,
          legPaint
            ..color = const Color(0xFF6F8FCB)
            ..strokeWidth = 6.4,
        );
        canvas.drawPath(
          path,
          legPaint
            ..color = const Color(0xFF8CAFE4)
            ..strokeWidth = 3.4,
        );
      } else {
        canvas.drawPath(
          path,
          legPaint
            ..color = skinShadow
            ..strokeWidth = 6.0,
        );
        canvas.drawPath(
          path,
          legPaint
            ..color = skin
            ..strokeWidth = 4.2,
        );
      }

      // 鞋：圆润的小短靴，脚尖朝前，随小腿方向微微转动。
      canvas.save();
      canvas.translate(a.dx, a.dy + 0.5);
      canvas.rotate((-shinAngle * 0.35).clamp(-0.6, 0.6));
      final shoe = RRect.fromRectAndRadius(
        Rect.fromLTWH(-3.6, -1.5, 11, 6.2),
        const Radius.circular(3.1),
      );
      canvas.drawRRect(
        shoe.shift(const Offset(0, 0.9)),
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
        const Offset(-2.4, 3.1),
        const Offset(6.2, 3.1),
        Paint()
          ..color = MacaronColors.rose.withValues(alpha: 0.55)
          ..strokeWidth = 1.1
          ..strokeCap = StrokeCap.round,
      );
      canvas.restore();
    }
  }

  void _drawArms(
    Canvas canvas,
    double height,
    double legSwing, {
    bool falling = false,
    bool pounding = false,
    double? runPhase,
  }) {
    final shoulderY = -height * 0.4;
    final handY = -height * 0.23;
    for (final side in [-1.0, 1.0]) {
      final shoulder = Offset(side * 9, shoulderY + 2);
      final armSwing = side < 0 ? -legSwing * 0.42 : legSwing * 0.42;
      // 跑步时手臂与同侧的腿反向前后摆，肘部半程、手到位，和腿的相位一致。
      final legPhase = (runPhase ?? 0) + (side < 0 ? 0 : math.pi);
      final swingX = runPhase == null ? 0.0 : -math.sin(legPhase) * 5.5;
      final elbow = falling
          ? Offset(side * 17, shoulderY - 3 + armSwing * 0.2)
          : pounding
          ? Offset(side * 16, shoulderY + 10 + armSwing * 0.2)
          : Offset(side * 12 + swingX * 0.5, shoulderY + 7 + armSwing * 0.35);
      final hand = falling
          ? Offset(side * 22, shoulderY - 10 + armSwing * 0.25)
          : pounding
          ? Offset(side * 21, shoulderY + 18 + armSwing * 0.2)
          : Offset(side * 14 + swingX, handY + armSwing * 0.5);
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

  void _drawOutfit(
    Canvas canvas,
    Color outfit,
    Color accent,
    double height, {
    double hemSwing = 0,
  }) {
    if (role == PlayerRole.boyfriend) {
      _drawBoyfriendOutfit(canvas, outfit, accent, height);
      return;
    }
    final shoulderY = -height * 0.43;
    final waistY = -height * 0.3;
    // 裙摆上提，露出小腿，身材更修长。
    const hemY = -17.0;
    final skirt = Path()
      ..moveTo(-4.5, shoulderY)
      ..quadraticBezierTo(0, shoulderY - 3, 4.5, shoulderY)
      ..cubicTo(
        9,
        shoulderY + 2,
        9 + hemSwing,
        waistY - 3,
        15 + hemSwing,
        hemY - 1,
      )
      ..quadraticBezierTo(
        hemSwing * 0.35,
        hemY + 3,
        -15 + hemSwing * 0.2,
        hemY - 1,
      )
      ..cubicTo(-9, waistY - 3, -9, shoulderY + 2, -4.5, shoulderY)
      ..close();
    // 裙子用深色（和浅蓝吊带分开）：冷静、利落。强化状态下仍跟着上衣色。
    final skirtBase = outfit == const Color(0xFFBBD7F0)
        ? const Color(0xFF3B3A52)
        : outfit;
    final bounds = Rect.fromLTRB(-17, shoulderY - 3, 17, hemY + 4);
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
            Color.lerp(Colors.white, skirtBase, 0.18)!,
            skirtBase,
            Color.lerp(skirtBase, accent, 0.3)!,
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
    // 浅蓝细肩带吊带：露出肩膀和锁骨，V 领，领口一条细项链。
    final camisole = Path()
      ..moveTo(-7.8, shoulderY + 5)
      ..lineTo(-4.6, shoulderY + 5)
      ..lineTo(0, shoulderY + 12.5)
      ..lineTo(4.6, shoulderY + 5)
      ..lineTo(7.8, shoulderY + 5)
      ..lineTo(8.4, waistY + 4)
      ..lineTo(-8.4, waistY + 4)
      ..close();
    canvas.drawPath(
      camisole,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(outfit, Colors.white, 0.55)!,
            outfit,
            Color.lerp(outfit, accent, 0.18)!,
          ],
        ).createShader(Rect.fromLTRB(-9, shoulderY, 9, waistY + 5)),
    );
    canvas.drawPath(
      camisole,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.9
        ..strokeJoin = StrokeJoin.round,
    );
    // 胸口的 V 形肌肤和锁骨。
    final chest = Path()
      ..moveTo(-4.6, shoulderY + 4.6)
      ..lineTo(0, shoulderY + 12.2)
      ..lineTo(4.6, shoulderY + 4.6)
      ..close();
    canvas.drawPath(chest, Paint()..color = const Color(0xFFFFE4D6));
    canvas.drawLine(
      Offset(-4.2, shoulderY + 3.2),
      Offset(-0.8, shoulderY + 4.2),
      Paint()
        ..color = const Color(0xFFD9A094).withValues(alpha: 0.6)
        ..strokeWidth = 0.7
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      Offset(4.2, shoulderY + 3.2),
      Offset(0.8, shoulderY + 4.2),
      Paint()
        ..color = const Color(0xFFD9A094).withValues(alpha: 0.6)
        ..strokeWidth = 0.7
        ..strokeCap = StrokeCap.round,
    );
    // 肩带。
    for (final side in [-1.0, 1.0]) {
      canvas.drawLine(
        Offset(side * 5.2, shoulderY + 0.2),
        Offset(side * 6.2, shoulderY + 5.2),
        Paint()
          ..color = Color.lerp(outfit, Colors.white, 0.4)!
          ..strokeWidth = 1.5
          ..strokeCap = StrokeCap.round,
      );
    }
    // 项链：细金链加一颗小坠子。
    final chain = Path()
      ..moveTo(-3.6, shoulderY + 1.6)
      ..quadraticBezierTo(0, shoulderY + 10, 3.6, shoulderY + 1.6);
    canvas.drawPath(
      chain,
      Paint()
        ..color = const Color(0xFFE6C27A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.7,
    );
    canvas.drawCircle(
      Offset(0, shoulderY + 8.2),
      1.15,
      Paint()..color = const Color(0xFFF3D78F),
    );
    canvas.drawCircle(
      Offset(-0.3, shoulderY + 7.9),
      0.4,
      Paint()..color = Colors.white.withValues(alpha: 0.9),
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
    // 腰扣：一小颗金色圆扣。
    canvas.drawCircle(
      Offset(0, waistY + 2),
      2.1,
      Paint()..color = const Color(0xFFE6C27A),
    );
    canvas.drawCircle(
      Offset(-0.5, waistY + 1.5),
      0.7,
      Paint()..color = Colors.white.withValues(alpha: 0.85),
    );
    canvas.drawLine(
      Offset(-12, hemY - 1.3),
      Offset(12, hemY - 1.3),
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
        center: Offset(side * 9, shoulderY + 6),
        width: 7.5,
        height: 11,
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
    if (role == PlayerRole.girlfriend) {
      _drawGirlFace(canvas, center);
      return;
    }
    const skin = Color(0xFFFFE4D6);
    final irisTop = role == PlayerRole.girlfriend
        ? (poweredUp ? const Color(0xFFFF82A8) : const Color(0xFFBD7895))
        : const Color(0xFF77A8E4);
    final irisBottom = role == PlayerRole.girlfriend
        ? const Color(0xFF65445F)
        : const Color(0xFF354B78);
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
        final eyeWhite = Rect.fromCenter(center: eye, width: 6.0, height: 7.8);
        canvas.drawOval(eyeWhite, Paint()..color = Colors.white);
        final iris = Rect.fromCenter(
          center: eye.translate(0.45, 0.8),
          width: 4.6,
          height: 6.4,
        );
        canvas.drawOval(
          iris,
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [irisTop, irisBottom],
            ).createShader(iris),
        );
        canvas.drawOval(
          iris,
          Paint()
            ..color = MacaronColors.cocoa.withValues(alpha: 0.3)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.55,
        );
        canvas.drawCircle(
          eye.translate(-0.45, -0.85),
          1.35,
          Paint()..color = Colors.white,
        );
        canvas.drawCircle(
          eye.translate(1.25, 1.65),
          0.55,
          Paint()..color = Colors.white.withValues(alpha: 0.78),
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
    final grin = velocity.x.abs() > 10 ? 2.2 : 0.0;
    final smile = Path()
      ..moveTo(center.dx - 3 - grin * 0.3, center.dy + 8)
      ..quadraticBezierTo(
        center.dx,
        center.dy + 11 + grin,
        center.dx + 3 + grin * 0.3,
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
        Paint()..color = MacaronColors.rose.withValues(alpha: 0.22),
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
    _drawLongHairFront(canvas, center, accent);
  }

  // ───────── 女主：长发、刘海、更细腻的五官（原创形象） ─────────

  Color _hairShade(Color base, double t) => t < 0
      ? Color.lerp(base, Colors.black, -t)!
      : Color.lerp(base, Colors.white, t)!;

  /// 身后的长发：披过肩膀垂到腰际，跑动时发梢摆动。
  void _drawLongHairBack(Canvas canvas, Offset c, Color base) {
    final sway = velocity.x.abs() > 10 ? math.sin(_anim * 0.42) * 5.0 : 0.0;
    final len = 50.0;
    final hair = Path()
      ..moveTo(c.dx - 16, c.dy - 5)
      ..cubicTo(
        c.dx - 22,
        c.dy + 8,
        c.dx - 21,
        c.dy + len * 0.6,
        c.dx - 15 + sway,
        c.dy + len,
      )
      ..quadraticBezierTo(
        c.dx + sway * 1.3,
        c.dy + len + 4,
        c.dx + 15 + sway,
        c.dy + len,
      )
      ..cubicTo(
        c.dx + 21,
        c.dy + len * 0.6,
        c.dx + 22,
        c.dy + 8,
        c.dx + 16,
        c.dy - 5,
      )
      ..close();
    final bounds = Rect.fromLTWH(c.dx - 24, c.dy - 8, 48, len + 12);
    canvas.drawPath(
      hair,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_hairShade(base, -0.08), base, _hairShade(base, -0.3)],
        ).createShader(bounds),
    );
    // 发丝高光：几道细长的亮线，顺着发流方向。
    for (final (dx, w) in [
      (-12.0, 1.3),
      (-6.0, 0.9),
      (7.0, 0.9),
      (13.0, 1.3),
    ]) {
      canvas.drawPath(
        Path()
          ..moveTo(c.dx + dx, c.dy + 2)
          ..quadraticBezierTo(
            c.dx + dx * 1.15,
            c.dy + len * 0.5,
            c.dx + dx * 0.95 + sway * 0.8,
            c.dy + len - 5,
          ),
        Paint()
          ..color = _hairShade(base, 0.38).withValues(alpha: 0.38)
          ..style = PaintingStyle.stroke
          ..strokeWidth = w
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  /// 头顶和刘海：略偏分的空气刘海，鬓边两缕垂在肩前。
  void _drawLongHairFront(Canvas canvas, Offset c, Color base) {
    final sway = velocity.x.abs() > 10 ? math.sin(_anim * 0.42) * 3.5 : 0.0;
    final shade = _hairShade(base, -0.2);
    final light = _hairShade(base, 0.22);
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [light, base, shade],
      ).createShader(Rect.fromLTWH(c.dx - 20, c.dy - 22, 40, 30));
    // 头顶的发盖。
    final crown = Path()
      ..moveTo(c.dx - 17.5, c.dy + 3)
      ..cubicTo(c.dx - 21, c.dy - 14, c.dx - 9, c.dy - 22, c.dx + 1, c.dy - 21)
      ..cubicTo(
        c.dx + 12,
        c.dy - 22,
        c.dx + 21,
        c.dy - 13,
        c.dx + 17.5,
        c.dy + 3,
      )
      ..lineTo(c.dx + 14, c.dy - 3)
      ..quadraticBezierTo(c.dx + 9, c.dy - 12, c.dx + 2, c.dy - 13)
      ..quadraticBezierTo(c.dx - 8, c.dy - 13, c.dx - 14, c.dy - 3)
      ..close();
    canvas.drawPath(crown, paint);
    // 空气刘海：从右偏分处向左下扫开，边缘稀疏，露出一点额头。
    final bangs = Path()
      ..moveTo(c.dx + 4, c.dy - 18)
      ..cubicTo(c.dx - 4, c.dy - 17, c.dx - 14, c.dy - 10, c.dx - 17, c.dy + 4)
      ..quadraticBezierTo(c.dx - 11, c.dy - 2, c.dx - 7, c.dy - 6)
      ..quadraticBezierTo(c.dx - 2, c.dy - 9, c.dx + 4, c.dy - 18)
      ..close();
    canvas.drawPath(bangs, paint);
    final rightBangs = Path()
      ..moveTo(c.dx + 4, c.dy - 18)
      ..cubicTo(
        c.dx + 12,
        c.dy - 17,
        c.dx + 18,
        c.dy - 8,
        c.dx + 17.5,
        c.dy + 4,
      )
      ..quadraticBezierTo(c.dx + 12, c.dy - 3, c.dx + 8, c.dy - 7)
      ..quadraticBezierTo(c.dx + 5, c.dy - 10, c.dx + 4, c.dy - 18)
      ..close();
    canvas.drawPath(rightBangs, paint);
    // 刘海上的几根发丝和头顶的亮光。
    for (final (x1, y1, x2, y2) in [
      (2.0, -16.0, -9.0, -6.0),
      (1.0, -17.0, -13.0, -2.0),
      (5.0, -17.0, 13.0, -5.0),
    ]) {
      canvas.drawLine(
        c.translate(x1, y1),
        c.translate(x2, y2),
        Paint()
          ..color = shade.withValues(alpha: 0.55)
          ..strokeWidth = 0.7
          ..strokeCap = StrokeCap.round,
      );
    }
    canvas.drawPath(
      Path()
        ..moveTo(c.dx - 9, c.dy - 17)
        ..quadraticBezierTo(c.dx - 2, c.dy - 20, c.dx + 7, c.dy - 18),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..strokeCap = StrokeCap.round,
    );
    // 鬓边的两缕：垂在脸颊两侧，落到肩前。
    for (final side in [-1.0, 1.0]) {
      final end = side < 0 ? 36.0 : 31.0;
      final lock = Path()
        ..moveTo(c.dx + side * 15, c.dy - 4)
        ..cubicTo(
          c.dx + side * 19,
          c.dy + 6,
          c.dx + side * 17,
          c.dy + end * 0.6,
          c.dx + side * 14 + sway * side * 0.4,
          c.dy + end,
        )
        ..quadraticBezierTo(
          c.dx + side * 11.5,
          c.dy + end * 0.55,
          c.dx + side * 12.5,
          c.dy + 3,
        )
        ..quadraticBezierTo(
          c.dx + side * 12.5,
          c.dy - 1,
          c.dx + side * 15,
          c.dy - 4,
        )
        ..close();
      canvas.drawPath(
        lock,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [base, shade],
          ).createShader(Rect.fromLTWH(c.dx - 22, c.dy - 4, 44, end + 4)),
      );
    }
  }

  /// 更细腻的脸：窄下巴、杏仁眼（眼线、双眼皮、睫毛）、细眉、鼻影、有光泽的唇。
  void _drawGirlFace(Canvas canvas, Offset c) {
    const skin = Color(0xFFFFE6DA);
    final iris1 = poweredUp ? const Color(0xFFD86A92) : const Color(0xFFB0705A);
    const iris2 = Color(0xFF4A2230);
    final face = Path()
      ..moveTo(c.dx - 14.6, c.dy - 3)
      ..cubicTo(
        c.dx - 14.6,
        c.dy - 14,
        c.dx - 7,
        c.dy - 17.5,
        c.dx,
        c.dy - 17.5,
      )
      ..cubicTo(
        c.dx + 7,
        c.dy - 17.5,
        c.dx + 14.6,
        c.dy - 14,
        c.dx + 14.6,
        c.dy - 3,
      )
      ..cubicTo(c.dx + 14.2, c.dy + 8, c.dx + 7.5, c.dy + 16, c.dx, c.dy + 17.6)
      ..cubicTo(
        c.dx - 7.5,
        c.dy + 16,
        c.dx - 14.2,
        c.dy + 8,
        c.dx - 14.6,
        c.dy - 3,
      )
      ..close();
    final bounds = Rect.fromCenter(center: c, width: 30, height: 36);
    // 耳朵（被头发遮住大半）。
    for (final side in [-1.0, 1.0]) {
      canvas.drawOval(
        Rect.fromCenter(
          center: c.translate(side * 14.6, 1.5),
          width: 4.2,
          height: 6.4,
        ),
        Paint()..color = const Color(0xFFF7CFC0),
      );
    }
    canvas.drawPath(
      face.shift(const Offset(0.8, 1.5)),
      Paint()..color = const Color(0xFFB77C74).withValues(alpha: 0.18),
    );
    canvas.drawPath(
      face,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFF3EA), skin, Color(0xFFF6C9BC)],
        ).createShader(bounds),
    );
    // 脸侧的淡阴影，让脸更立体。
    canvas.drawPath(
      face,
      Paint()
        ..color = const Color(0xFFC4857B).withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );
    for (final side in [-1.0, 1.0]) {
      canvas.drawPath(
        Path()
          ..moveTo(c.dx + side * 13.6, c.dy + 1)
          ..quadraticBezierTo(
            c.dx + side * 11.5,
            c.dy + 12,
            c.dx + side * 3.5,
            c.dy + 16.4,
          ),
        Paint()
          ..color = const Color(0xFFD99C92).withValues(alpha: 0.28)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2
          ..strokeCap = StrokeCap.round,
      );
    }
    final hairDark = const Color(0xFF4A1620);
    for (final side in [-1.0, 1.0]) {
      final e = c.translate(side * 6.4, 1.6);
      final inner = e.translate(-side * 3.7, 0.7);
      final outer = e.translate(side * 4.2, -0.5);
      final upper = Path()
        ..moveTo(inner.dx, inner.dy)
        ..quadraticBezierTo(e.dx - side * 0.4, e.dy - 5.2, outer.dx, outer.dy);
      final lower = Path()
        ..moveTo(outer.dx, outer.dy)
        ..quadraticBezierTo(e.dx + side * 0.2, e.dy + 3.4, inner.dx, inner.dy);
      final eyePath = Path()
        ..addPath(upper, Offset.zero)
        ..addPath(lower, Offset.zero)
        ..close();
      if (_eyesClosed) {
        canvas.drawPath(
          Path()
            ..moveTo(inner.dx, inner.dy)
            ..quadraticBezierTo(e.dx, e.dy + 2.2, outer.dx, outer.dy),
          Paint()
            ..color = hairDark
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..strokeCap = StrokeCap.round,
        );
      } else {
        canvas.drawPath(eyePath, Paint()..color = const Color(0xFFFFFAF6));
        canvas.save();
        canvas.clipPath(eyePath);
        final iris = Rect.fromCenter(
          center: e.translate(side * 0.3, 0.2),
          width: 5.6,
          height: 6.4,
        );
        canvas.drawOval(
          iris,
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [iris1, iris2],
            ).createShader(iris),
        );
        canvas.drawCircle(
          e.translate(side * 0.3, 0.3),
          1.45,
          Paint()..color = const Color(0xFF1C0C12),
        );
        // 上眼睑的投影压在眼球上方。
        canvas.drawPath(
          upper,
          Paint()
            ..color = Colors.black.withValues(alpha: 0.35)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.8,
        );
        canvas.restore();
        canvas.drawCircle(
          e.translate(-0.7, -0.9),
          1.0,
          Paint()..color = Colors.white,
        );
        canvas.drawCircle(
          e.translate(1.1, 1.3),
          0.5,
          Paint()..color = Colors.white.withValues(alpha: 0.75),
        );
      }
      // 上眼线（粗）、眼尾上挑、下眼线（细）。
      canvas.drawPath(
        upper,
        Paint()
          ..color = hairDark
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawLine(
        outer,
        outer.translate(side * 2.0, -1.4),
        Paint()
          ..color = hairDark
          ..strokeWidth = 1.2
          ..strokeCap = StrokeCap.round,
      );
      for (var i = 0; i < 2; i++) {
        final f = 0.62 + i * 0.2;
        final base = Offset.lerp(
          inner,
          outer,
          f,
        )!.translate(0, -2.9 - (1 - (f - 0.7).abs()) * 1.4);
        canvas.drawLine(
          base,
          base.translate(side * 0.9, -1.5),
          Paint()
            ..color = hairDark.withValues(alpha: 0.7)
            ..strokeWidth = 0.55
            ..strokeCap = StrokeCap.round,
        );
      }
      canvas.drawPath(
        lower,
        Paint()
          ..color = const Color(0xFF8A4F55).withValues(alpha: 0.4)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.6,
      );
      // 双眼皮的折线。
      canvas.drawPath(
        Path()
          ..moveTo(inner.dx + side * 1.2, inner.dy - 2.2)
          ..quadraticBezierTo(
            e.dx - side * 0.2,
            e.dy - 6.4,
            outer.dx + side * 0.6,
            outer.dy - 2.3,
          ),
        Paint()
          ..color = const Color(0xFFB57A78).withValues(alpha: 0.55)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.6
          ..strokeCap = StrokeCap.round,
      );
      // 细而微挑的眉。
      canvas.drawPath(
        Path()
          ..moveTo(c.dx + side * 3.2, c.dy - 6.4)
          ..quadraticBezierTo(
            c.dx + side * 7.2,
            c.dy - 9.4,
            c.dx + side * 11.2,
            c.dy - 7.2,
          ),
        Paint()
          ..color = hairDark.withValues(alpha: 0.78)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.1
          ..strokeCap = StrokeCap.round,
      );
    }
    // 鼻：鼻梁的一道淡影和鼻翼。
    canvas.drawPath(
      Path()
        ..moveTo(c.dx + 0.5, c.dy)
        ..quadraticBezierTo(c.dx + 1.3, c.dy + 3, c.dx + 0.7, c.dy + 5.2),
      Paint()
        ..color = const Color(0xFFD59B90).withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.9
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(
      c.translate(-0.7, 5.5),
      0.55,
      Paint()..color = const Color(0xFFC98278).withValues(alpha: 0.8),
    );
    canvas.drawCircle(
      c.translate(1.9, 5.4),
      0.5,
      Paint()..color = const Color(0xFFC98278).withValues(alpha: 0.7),
    );
    // 唇：上唇有唇峰，下唇饱满带高光，嘴角微微上扬（跑动时更明显）。
    final lift = velocity.x.abs() > 10 ? 1.4 : 0.6;
    final m = c.translate(0, 10);
    final upperLip = Path()
      ..moveTo(m.dx - 4.2, m.dy - lift * 0.2)
      ..quadraticBezierTo(m.dx - 2, m.dy - 2.4, m.dx, m.dy - 1.2)
      ..quadraticBezierTo(m.dx + 2, m.dy - 2.4, m.dx + 4.2, m.dy - lift * 0.2)
      ..quadraticBezierTo(m.dx, m.dy + 0.9, m.dx - 4.2, m.dy - lift * 0.2)
      ..close();
    final lowerLip = Path()
      ..moveTo(m.dx - 4, m.dy - lift * 0.1)
      ..quadraticBezierTo(m.dx, m.dy + 4.2, m.dx + 4, m.dy - lift * 0.1)
      ..quadraticBezierTo(m.dx, m.dy + 0.8, m.dx - 4, m.dy - lift * 0.1)
      ..close();
    canvas.drawPath(lowerLip, Paint()..color = const Color(0xFFD9606F));
    canvas.drawPath(upperLip, Paint()..color = const Color(0xFFB8404F));
    canvas.drawOval(
      Rect.fromCenter(center: m.translate(0.4, 1.7), width: 2.6, height: 0.9),
      Paint()..color = Colors.white.withValues(alpha: 0.55),
    );
    // 淡淡的腮红。
    for (final side in [-1.0, 1.0]) {
      canvas.drawOval(
        Rect.fromCenter(
          center: c.translate(side * 9.6, 6.2),
          width: 6.5,
          height: 3.6,
        ),
        Paint()..color = const Color(0xFFF08A98).withValues(alpha: 0.2),
      );
    }
  }

  void _drawVehicle(Canvas canvas) {
    if (vehicleBoosting) {
      for (var i = 0; i < 3; i++) {
        canvas.drawLine(
          Offset(-43 - i * 7.0, -14 + i * 6.0),
          Offset(-33, -14 + i * 6.0),
          Paint()
            ..color = (i.isEven ? MacaronColors.lemon : Colors.white)
                .withValues(alpha: 0.8 - i * 0.15)
            ..strokeWidth = 3
            ..strokeCap = StrokeCap.round,
        );
      }
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-35, -20, 70, 22),
        const Radius.circular(9),
      ),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFFFFF), Color(0xFFE6E9EF), Color(0xFFB9C0CC)],
        ).createShader(const Rect.fromLTWH(-35, -20, 70, 22)),
    );
    drawCarLabel(canvas, const Offset(0, -9), 9, 0);
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
      canvas.save();
      canvas.translate(x, -1);
      canvas.rotate(_wheelSpin);
      canvas.drawLine(
        const Offset(-4, 0),
        const Offset(4, 0),
        Paint()
          ..color = MacaronColors.mint
          ..strokeWidth = 1.5,
      );
      canvas.restore();
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(27, -15, 6, 5),
        const Radius.circular(2),
      ),
      Paint()..color = MacaronColors.lemon,
    );
  }

  /// AK-47。
  void _drawCandyGun(Canvas canvas) {
    final y = -size.y * 0.48;
    final wood = Paint()..color = const Color(0xFF9A5B35);
    final steel = Paint()..color = const Color(0xFF3F4048);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(8, y + 1, 9, 6),
        const Radius.circular(2),
      ),
      wood,
    );
    canvas.drawRect(Rect.fromLTWH(16, y, 13, 5), steel);
    canvas.drawRect(Rect.fromLTWH(28, y + 1, 16, 2.5), steel);
    canvas.drawRect(Rect.fromLTWH(26, y + 4, 8, 2.5), wood);
    canvas.drawPath(
      Path()
        ..moveTo(20, y + 5)
        ..lineTo(25, y + 5)
        ..lineTo(26, y + 14)
        ..lineTo(21, y + 14)
        ..close(),
      Paint()..color = const Color(0xFF55565E),
    );
  }

  void _drawPeaBuddy(Canvas canvas) {
    final bob = math.sin(_anim * 0.55) * 1.5;
    final recoil = _plantShotTimer / 0.18;
    canvas.save();
    canvas.translate(1, 0);
    canvas.scale(plantFacingRight == facingRight ? 1.0 : -1.0, 1.0);
    canvas.translate(-1 - recoil * 2, 0);
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
    canvas.drawCircle(
      Offset(-1, -size.y * 1.03 + bob - 3),
      1.4,
      Paint()..color = MacaronColors.cocoa,
    );
    canvas.drawCircle(
      Offset(-3, -size.y * 1.03 + bob - 5),
      2,
      Paint()..color = Colors.white.withValues(alpha: 0.75),
    );
    if (recoil > 0) {
      canvas.drawCircle(
        Offset(13, -size.y * 1.03 + bob),
        2 + recoil * 2,
        Paint()..color = MacaronColors.mint.withValues(alpha: recoil * 0.8),
      );
    }
    canvas.restore();
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
