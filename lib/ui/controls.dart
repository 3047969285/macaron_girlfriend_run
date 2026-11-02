import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:macaron_girlfriend_run/data/save_service.dart';
import 'package:macaron_girlfriend_run/theme/macaron_colors.dart';

/// 高刷帧率适配（Android 可切换；iOS 跟随系统 ProMotion）
class FpsBootstrap {
  FpsBootstrap._();

  /// 只有 Android 原生能切刷新率。测试可用 debugDefaultTargetPlatformOverride 覆盖。
  static bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// 按存档档位尽量拉高刷新率
  static Future<void> applyFromSave() async {
    final mode = SaveService.instance.fpsMode;
    await applyMode(mode);
  }

  static Future<void> applyMode(int mode) async {
    try {
      final modes = await FlutterDisplayMode.supported;
      if (modes.isEmpty) {
        return;
      }
      late final DisplayMode pick;
      switch (mode) {
        case 1:
          pick = _closest(modes, 60);
          break;
        case 2:
          pick = _closest(modes, 90);
          break;
        case 3:
          pick = _closest(modes, 120);
          break;
        default:
          pick = modes.reduce((a, b) => a.refreshRate >= b.refreshRate ? a : b);
      }
      await FlutterDisplayMode.setPreferredMode(pick);
    } catch (_) {}
  }

  static DisplayMode _closest(List<DisplayMode> modes, double target) {
    return modes.reduce((a, b) {
      final da = (a.refreshRate - target).abs();
      final db = (b.refreshRate - target).abs();
      return da <= db ? a : b;
    });
  }
}

/// 虚拟轮盘与跳跃、技能键。
///
/// 布局按拇指够得到的位置排：左下角是小轮盘（推到底自动奔跑）；右下角竖排，跳在上、
/// 蹲在下；技能和射击在它们左边；“跑”是开关，放在底部中间，两根拇指都够得着。
class TouchControls extends StatefulWidget {
  const TouchControls({
    super.key,
    required this.onLeft,
    required this.onRight,
    required this.onRun,
    required this.onJumpHeld,
    this.onDuck,
    this.onInteract,
    this.onSkill,
    this.onCycleSkill,
    this.onShoot,
    this.skillCooldown = 0,
    this.skillLabel = '冲刺',
    this.scale = 1,
  });

  final ValueChanged<bool> onLeft;
  final ValueChanged<bool> onRight;
  final ValueChanged<bool> onRun;
  final ValueChanged<bool> onJumpHeld;
  final ValueChanged<bool>? onDuck;
  final VoidCallback? onInteract;
  final VoidCallback? onSkill;

  /// 非空时，在技能键旁显示文字为「换」的小按钮，点按调用它。
  final VoidCallback? onCycleSkill;
  final ValueChanged<bool>? onShoot;
  final double skillCooldown;
  final String skillLabel;
  final double scale;

  @override
  State<TouchControls> createState() => _TouchControlsState();
}

class _TouchControlsState extends State<TouchControls> {
  static const double _wheelSize = 104;

  /// 最大的“跑”键：中心距右下角的横向 / 纵向距离和直径。
  static const double _runRx = 52;
  static const double _runBy = 52;
  static const double _runSize = 88;

  /// 其余按钮围着“跑”的弧线半径。
  static const double _arcRadius = 114;
  static const double _baseWidth = 385;
  static const double _baseHeight = 200;

  /// 点“跑”切换常驻奔跑；轮盘推到底也会奔跑，两者任一为真就在跑。
  bool _runToggled = false;
  bool _wheelRun = false;
  bool _runSent = false;

  void _syncRun() {
    final run = _runToggled || _wheelRun;
    if (run != _runSent) {
      _runSent = run;
      widget.onRun(run);
    }
  }

  @override
  void dispose() {
    if (_runSent) {
      widget.onRun(false);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    final width = MediaQuery.sizeOf(context).width;
    final available = width - pad.left - pad.right - 16;
    final maxScale = (available / _baseWidth).clamp(0.6, 1.25);
    final s = widget.scale.clamp(0.6, maxScale).toDouble();
    final rightPad = 10.0 + pad.right;
    final bottomPad = 8.0 + pad.bottom;

    // 以屏幕右下角为原点量中心点（向左 rx，向上 by），统一放置圆形按钮。
    Widget place(double rx, double by, double size, Widget child) {
      return Positioned(
        right: rightPad + (rx - size / 2) * s,
        bottom: bottomPad + (by - size / 2) * s,
        width: size * s,
        height: size * s,
        child: child,
      );
    }

    // 在以“跑”为圆心的弧线上放按钮：角度从正左（0°）逆时针往正上方（90°）数。
    Widget arc(double degrees, double size, Widget child) {
      final a = degrees * math.pi / 180;
      return place(
        _runRx + _arcRadius * math.cos(a),
        _runBy + _arcRadius * math.sin(a),
        size,
        child,
      );
    }

    final hasCycle = widget.onCycleSkill != null && widget.onSkill != null;
    final children = <Widget>[
      Positioned(
        left: 10.0 + pad.left,
        bottom: bottomPad,
        width: _wheelSize * s,
        height: _wheelSize * s,
        child: _MoveWheel(
          onLeft: widget.onLeft,
          onRight: widget.onRight,
          onFull: (full) {
            _wheelRun = full;
            _syncRun();
          },
          onInteract: widget.onInteract,
        ),
      ),
      // 王者荣耀式排布：最大的“跑”在右下角正中，其余按钮沿弧线围着它——
      // 蹲在左边靠下，闪冲在斜上方，跳在最上面。
      place(
        _runRx,
        _runBy,
        _runSize,
        _ToggleButton(
          label: '跑',
          on: _runToggled,
          fill: MacaronColors.mint,
          fontSize: 24,
          onInteract: widget.onInteract,
          onToggle: () {
            setState(() => _runToggled = !_runToggled);
            _syncRun();
          },
        ),
      ),
      if (widget.onDuck != null)
        arc(
          5,
          54,
          _RoundHold(
            label: '蹲',
            onChanged: widget.onDuck!,
            onInteract: widget.onInteract,
            fill: MacaronColors.lilac.withValues(alpha: 0.88),
            size: 54 * s,
          ),
        ),
      if (widget.onSkill != null)
        arc(
          40,
          58,
          _SkillButton(
            onPressed: widget.onSkill!,
            onInteract: widget.onInteract,
            cooldown: widget.skillCooldown,
            label: widget.skillLabel,
            size: 58 * s,
          ),
        ),
      arc(
        78,
        66,
        _RoundHold(
          label: '跳',
          onChanged: widget.onJumpHeld,
          onInteract: widget.onInteract,
          fill: MacaronColors.blush.withValues(alpha: 0.95),
          size: 66 * s,
        ),
      ),
      // 射击和“换”放在外圈，不挤占拇指最常用的那一圈。
      if (widget.onShoot != null)
        place(
          224,
          58,
          48,
          _RoundHold(
            label: '射击',
            onChanged: widget.onShoot!,
            onInteract: widget.onInteract,
            fill: MacaronColors.rose.withValues(alpha: 0.9),
            size: 48 * s,
          ),
        ),
      if (hasCycle)
        place(
          214,
          122,
          30,
          _CycleButton(
            onCycle: widget.onCycleSkill!,
            onInteract: widget.onInteract,
            size: 30 * s,
          ),
        ),
    ];

    return SizedBox(
      width: double.infinity,
      height: (_baseHeight + 8) * s + bottomPad,
      child: Stack(children: children),
    );
  }
}

/// 点一下切换的圆形按钮（开着时变实心加粗描边）。
class _ToggleButton extends StatelessWidget {
  const _ToggleButton({
    required this.label,
    required this.on,
    required this.fill,
    required this.onToggle,
    this.fontSize = 18,
    this.onInteract,
  });

  final String label;
  final bool on;
  final double fontSize;
  final Color fill;
  final VoidCallback onToggle;
  final VoidCallback? onInteract;

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (_) {
        onInteract?.call();
        onToggle();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: fill.withValues(alpha: on ? 1.0 : 0.6),
          border: Border.all(
            color: Colors.white.withValues(alpha: on ? 1.0 : 0.65),
            width: on ? 3 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: on
                  ? fill.withValues(alpha: 0.55)
                  : const Color(0x18000000),
              blurRadius: on ? 14 : 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: on ? FontWeight.w900 : FontWeight.w600,
            color: MacaronColors.cocoa,
          ),
        ),
      ),
    );
  }
}

/// 轮盘：按住拖动，向左/向右超过死区即触发对应方向，松开归零。
class _MoveWheel extends StatefulWidget {
  const _MoveWheel({
    required this.onLeft,
    required this.onRight,
    required this.onFull,
    this.onInteract,
  });

  final ValueChanged<bool> onLeft;
  final ValueChanged<bool> onRight;

  /// 轮盘被推到底（接近最大行程）时为 true，用来触发奔跑。
  final ValueChanged<bool> onFull;
  final VoidCallback? onInteract;

  @override
  State<_MoveWheel> createState() => _MoveWheelState();
}

class _MoveWheelState extends State<_MoveWheel> {
  /// 死区：偏移超过半径的这个比例才算方向，进入后再放宽一点防止抖动。
  static const double _engage = 0.28;
  static const double _release = 0.18;

  int? _pointer;
  int _dir = 0;
  Offset _knob = Offset.zero;

  void _update(Offset local, Size size) {
    final radius = size.width / 2;
    final delta = local - Offset(radius, radius);
    final limit = radius * 0.55;
    final clamped = delta.distance > limit
        ? delta / delta.distance * limit
        : delta;
    final ratio = clamped.dx / radius;
    var dir = _dir;
    if (dir == 0) {
      if (ratio > _engage) {
        dir = 1;
      } else if (ratio < -_engage) {
        dir = -1;
      }
    } else if (dir == 1 && ratio < _release) {
      dir = ratio < -_engage ? -1 : 0;
    } else if (dir == -1 && ratio > -_release) {
      dir = ratio > _engage ? 1 : 0;
    }
    _setDir(dir);
    _setFull(clamped.dx.abs() >= limit * 0.9);
    setState(() => _knob = clamped);
  }

  bool _full = false;

  void _setFull(bool value) {
    if (value != _full) {
      _full = value;
      widget.onFull(value);
    }
  }

  void _setDir(int dir) {
    if (dir == _dir) {
      return;
    }
    if (_dir == -1) {
      widget.onLeft(false);
    } else if (_dir == 1) {
      widget.onRight(false);
    }
    _dir = dir;
    if (dir == -1) {
      widget.onLeft(true);
    } else if (dir == 1) {
      widget.onRight(true);
    }
  }

  void _end() {
    _pointer = null;
    _setDir(0);
    _setFull(false);
    setState(() => _knob = Offset.zero);
  }

  @override
  void dispose() {
    if (_dir != 0) {
      _setDir(0);
    }
    if (_full) {
      widget.onFull(false);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final knobSize = size.width * 0.42;
        return Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (event) {
            if (_pointer != null) {
              return;
            }
            _pointer = event.pointer;
            widget.onInteract?.call();
            _update(event.localPosition, size);
          },
          onPointerMove: (event) {
            if (event.pointer == _pointer) {
              _update(event.localPosition, size);
            }
          },
          onPointerUp: (event) {
            if (event.pointer == _pointer) {
              _end();
            }
          },
          onPointerCancel: (event) {
            if (event.pointer == _pointer) {
              _end();
            }
          },
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(
                    alpha: _pointer == null ? 0.22 : 0.4,
                  ),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.8),
                    width: 2,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x1A000000),
                      blurRadius: 14,
                      offset: Offset(0, 5),
                    ),
                  ],
                ),
              ),
              Positioned(
                left: size.width * 0.1,
                child: Icon(
                  CupertinoIcons.left_chevron,
                  size: size.width * 0.14,
                  color: MacaronColors.cocoa.withValues(
                    alpha: _dir == -1 ? 0.8 : 0.3,
                  ),
                ),
              ),
              Positioned(
                right: size.width * 0.1,
                child: Icon(
                  CupertinoIcons.right_chevron,
                  size: size.width * 0.14,
                  color: MacaronColors.cocoa.withValues(
                    alpha: _dir == 1 ? 0.8 : 0.3,
                  ),
                ),
              ),
              Transform.translate(
                offset: _knob,
                child: Container(
                  width: knobSize,
                  height: knobSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const RadialGradient(
                      center: Alignment(-0.3, -0.4),
                      colors: [Color(0xFFFFFFFF), Color(0xFFFFD6E4)],
                    ),
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x26000000),
                        blurRadius: 8,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// 技能键旁的「换」按钮：点一下切换选中技能，复用 _RoundHold 的按压手感。
class _CycleButton extends StatelessWidget {
  const _CycleButton({
    required this.onCycle,
    required this.size,
    this.onInteract,
  });

  final VoidCallback onCycle;
  final VoidCallback? onInteract;
  final double size;

  @override
  Widget build(BuildContext context) {
    return _RoundHold(
      label: '换',
      size: size,
      fill: MacaronColors.lemon.withValues(alpha: 0.95),
      onInteract: onInteract,
      onChanged: (down) {
        if (down) {
          onCycle();
        }
      },
    );
  }
}

class _SkillButton extends StatefulWidget {
  const _SkillButton({
    required this.onPressed,
    required this.cooldown,
    required this.label,
    this.onInteract,
    required this.size,
  });

  final VoidCallback onPressed;
  final VoidCallback? onInteract;
  final double cooldown;
  final String label;
  final double size;

  @override
  State<_SkillButton> createState() => _SkillButtonState();
}

class _SkillButtonState extends State<_SkillButton> {
  bool _down = false;

  void _setPressed(bool value) {
    if (_down == value) {
      return;
    }
    setState(() => _down = value);
    if (value) {
      widget.onInteract?.call();
      widget.onPressed();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ratio = widget.cooldown.clamp(0.0, 1.0);
    final ready = ratio <= 0.001;
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (_) => _setPressed(true),
      onPointerUp: (_) => _setPressed(false),
      onPointerCancel: (_) => _setPressed(false),
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: AnimatedScale(
          duration: const Duration(milliseconds: 80),
          scale: _down ? 0.92 : 1,
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              color: MacaronColors.lilac.withValues(alpha: 0.94),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.9),
                width: 2,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x18000000),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: widget.size - 5,
                  height: widget.size - 5,
                  child: CircularProgressIndicator(
                    value: 1 - ratio,
                    strokeWidth: 3,
                    backgroundColor: MacaronColors.cocoa.withValues(
                      alpha: 0.12,
                    ),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      MacaronColors.lemon,
                    ),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      ready
                          ? CupertinoIcons.bolt_fill
                          : CupertinoIcons.hourglass,
                      size: 17,
                      color: MacaronColors.cocoa,
                    ),
                    Text(
                      widget.label,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: MacaronColors.cocoa,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoundHold extends StatefulWidget {
  const _RoundHold({
    required this.onChanged,
    this.onInteract,
    this.label,
    this.fill,
    this.size = 64,
  });

  final ValueChanged<bool> onChanged;
  final VoidCallback? onInteract;
  final String? label;
  final Color? fill;
  final double size;

  @override
  State<_RoundHold> createState() => _RoundHoldState();
}

class _RoundHoldState extends State<_RoundHold> {
  bool _down = false;

  void _set(bool v) {
    if (_down == v) {
      return;
    }
    setState(() => _down = v);
    if (v) {
      widget.onInteract?.call();
    }
    widget.onChanged(v);
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size * (_down ? 0.92 : 1.0);
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        width: widget.size,
        height: widget.size,
        alignment: Alignment.center,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: (widget.fill ?? Colors.white.withValues(alpha: 0.7))
                .withValues(alpha: _down ? 1.0 : 0.85),
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: _down ? 0.95 : 0.65),
              width: _down ? 2.5 : 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0x18000000),
                blurRadius: _down ? 8 : 16,
                offset: Offset(0, _down ? 3 : 6),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            widget.label ?? '',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: MacaronColors.cocoa,
            ),
          ),
        ),
      ),
    );
  }
}
