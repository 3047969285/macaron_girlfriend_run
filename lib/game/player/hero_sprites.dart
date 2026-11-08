import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/services.dart' show rootBundle;

/// 主角的写实立绘帧（透明背景 PNG，右侧面，同一条地面线）。
/// [anchorX]：身体中心距这一帧图片左边的像素；[bottomGap]：这一帧脚底离地面线的像素
/// （起跳那一帧在空中，所以是正数）。像素都是素材本身的尺寸，画的时候统一缩放。
class HeroFrame {
  const HeroFrame(
    this.asset,
    this.width,
    this.height,
    this.anchorX,
    this.bottomGap,
  );

  final String asset;
  final double width;
  final double height;
  final double anchorX;
  final double bottomGap;
}

enum HeroPose { stand, run1, run2, run3, run4, jump, fall, duck }

class HeroPoseAnimator {
  HeroPose? current;
  HeroPose? previous;
  double _age = 0;
  double _impulseAge = 1;
  double _impulse = 0;
  double _distance = 0;
  double _elapsed = 0;

  static const double strideLength = 96;
  double get stridePhase => (_distance % strideLength) / strideLength;
  double get idleScale => 1 + math.sin(_elapsed * 2.4) * 0.012;
  double get runBob => math.sin(stridePhase * math.pi * 4) * 1.4;
  double get runLean => 0.035 + math.sin(stridePhase * math.pi * 2) * 0.012;
  HeroPose get runPose => const [
    HeroPose.run1,
    HeroPose.run2,
    HeroPose.run3,
    HeroPose.run4,
  ][(stridePhase * 4).floor().clamp(0, 3)];

  void move(double distance, double dt, {required bool running}) {
    _elapsed += math.max(0.0, dt);
    if (running) _distance += distance.abs();
  }

  bool _isRunning(HeroPose? pose) =>
      pose == HeroPose.run1 ||
      pose == HeroPose.run2 ||
      pose == HeroPose.run3 ||
      pose == HeroPose.run4;

  List<(HeroPose, double)> layers(double alpha) => [
    if (current != null &&
        (_isRunning(current) ||
            _isRunning(previous) ||
            current == HeroPose.duck ||
            previous == HeroPose.duck))
      (current!, alpha)
    else ...[
      if (previous != null && previous != current && blend < 1)
        (previous!, alpha),
      if (current != null)
        (current!, previous == current ? alpha : alpha * blend),
    ],
  ];

  double get blend {
    final t = (_age / 0.14).clamp(0.0, 1.0);
    return t * t * (3 - 2 * t);
  }

  double get stretch => 1 + _impulse * math.exp(-_impulseAge * 10);

  void advance(HeroPose pose, double dt) {
    if (current == null) {
      current = previous = pose;
      _age = 0.14;
    } else if (current != pose) {
      previous = current;
      final airborne = current == HeroPose.jump || current == HeroPose.fall;
      final landing =
          airborne && pose != HeroPose.jump && pose != HeroPose.fall;
      if (pose == HeroPose.jump && !airborne) {
        _impulse = 0.12;
        _impulseAge = 0;
      } else if (landing) {
        _impulse = -0.13;
        _impulseAge = 0;
      }
      current = pose;
      _age = 0;
    }
    final elapsed = math.max(0.0, dt);
    _age += elapsed;
    _impulseAge += elapsed;
  }
}

class HeroSprites {
  HeroSprites._();

  static const Map<HeroPose, HeroFrame> frames = {
    HeroPose.stand: HeroFrame(
      'assets/character/stand.webp',
      131,
      425,
      61.0,
      -2.3,
    ),
    HeroPose.run1: HeroFrame('assets/character/run1.webp', 166, 421, 93.5, -1.1),
    HeroPose.run2: HeroFrame('assets/character/run2.webp', 145, 415, 75.8, 4.6),
    HeroPose.run3: HeroFrame('assets/character/run3.webp', 189, 412, 114.5, 7.4),
    HeroPose.run4: HeroFrame('assets/character/run4.webp', 146, 421, 73.5, -1.1),
    HeroPose.jump: HeroFrame('assets/character/jump.webp', 145, 376, 74.7, 62.7),
    HeroPose.fall: HeroFrame('assets/character/fall.webp', 180, 410, 76.4, 4.6),
    HeroPose.duck: HeroFrame('assets/character/duck.webp', 146, 287, 78.1, -2.8),
  };

  /// 站立那一帧的图片高度：缩放以它为基准，所有帧用同一个比例。
  static const double standImageHeight = 425;

  static final Map<HeroPose, ui.Image> _images = {};
  static Future<void>? _loading;
  static ui.Image? horseIdle;
  static ui.Image? horseRun;

  static bool get ready => _images.length == frames.length;

  /// 启动时调用一次（不必等它）；没加载完时角色退回矢量画法。
  static Future<void> preload() {
    return _loading ??= _load();
  }

  static Future<void> _load() async {
    try {
      for (final entry in frames.entries) {
        final data = await rootBundle.load(entry.value.asset);
        final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
        try {
          _images[entry.key] = (await codec.getNextFrame()).image;
        } finally {
          codec.dispose();
        }
      }
      for (final asset in ['white_horse_idle.webp', 'white_horse_run.webp']) {
        try {
          final data = await rootBundle.load('assets/character/$asset');
          final codec = await ui.instantiateImageCodec(
            data.buffer.asUint8List(),
          );
          final image = (await codec.getNextFrame()).image;
          codec.dispose();
          if (asset == 'white_horse_idle.webp') {
            horseIdle = image;
          } else {
            horseRun = image;
          }
        } catch (_) {
          // The normal player frames remain available if a mount image fails.
        }
      }
    } catch (_) {
      _images.clear();
      _loading = null;
    }
  }

  /// 画一帧：脚底落在 (0, 0)，身体中心在 x = 0；[standHeight] 是站立时人物的屏幕高度。
  static void draw(
    ui.Canvas canvas,
    double standHeight, {
    required HeroPoseAnimator animator,
    double alpha = 1,
  }) {
    canvas.save();
    canvas.scale(1 / animator.stretch, animator.stretch);
    for (final (frame, opacity) in animator.layers(alpha)) {
      _drawFrame(canvas, frame, standHeight, opacity);
    }
    canvas.restore();
  }

  static void _drawFrame(
    ui.Canvas canvas,
    HeroPose pose,
    double standHeight,
    double alpha,
  ) {
    final image = _images[pose];
    final frame = frames[pose];
    if (image == null || frame == null) {
      return;
    }
    final s = standHeight / standImageHeight;
    final dst = ui.Rect.fromLTWH(
      -frame.anchorX * s,
      -(frame.height + frame.bottomGap) * s,
      frame.width * s,
      frame.height * s,
    );
    final src = ui.Rect.fromLTWH(
      0,
      0,
      image.width.toDouble(),
      image.height.toDouble(),
    );
    canvas.drawImageRect(
      image,
      src,
      dst,
      ui.Paint()
        ..filterQuality = ui.FilterQuality.medium
        ..color = ui.Color.fromRGBO(255, 255, 255, alpha),
    );
  }
}
