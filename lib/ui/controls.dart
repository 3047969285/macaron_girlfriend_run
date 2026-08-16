import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:macaron_girlfriend_run/data/save_service.dart';
import 'package:macaron_girlfriend_run/theme/macaron_colors.dart';

/// 高刷帧率适配（Android 可切换；iOS 跟随系统 ProMotion）
class FpsBootstrap {
  FpsBootstrap._();

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
          pick = modes.reduce(
            (a, b) => a.refreshRate >= b.refreshRate ? a : b,
          );
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

/// 虚拟方向键与跳跑蹲键
class TouchControls extends StatelessWidget {
  const TouchControls({
    super.key,
    required this.onLeft,
    required this.onRight,
    required this.onRun,
    required this.onJumpHeld,
    this.onDuck,
    this.onInteract,
    this.scale = 1,
  });

  final ValueChanged<bool> onLeft;
  final ValueChanged<bool> onRight;
  final ValueChanged<bool> onRun;
  final ValueChanged<bool> onJumpHeld;
  final ValueChanged<bool>? onDuck;
  final VoidCallback? onInteract;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    final s = scale.clamp(0.85, 1.25);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        28 + pad.left,
        0,
        28 + pad.right,
        18 + pad.bottom,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Row(
            children: [
              _RoundHold(
                icon: CupertinoIcons.left_chevron,
                onChanged: onLeft,
                onInteract: onInteract,
                size: 64 * s,
              ),
              SizedBox(width: 14 * s),
              _RoundHold(
                icon: CupertinoIcons.right_chevron,
                onChanged: onRight,
                onInteract: onInteract,
                size: 64 * s,
              ),
            ],
          ),
          const Spacer(),
          Row(
            children: [
              if (onDuck != null) ...[
                _RoundHold(
                  label: '蹲',
                  onChanged: onDuck!,
                  onInteract: onInteract,
                  fill: MacaronColors.lilac.withValues(alpha: 0.85),
                  size: 62 * s,
                ),
                SizedBox(width: 12 * s),
              ],
              _RoundHold(
                label: '跑',
                onChanged: onRun,
                onInteract: onInteract,
                fill: MacaronColors.mint.withValues(alpha: 0.85),
                size: 64 * s,
              ),
              SizedBox(width: 14 * s),
              _RoundHold(
                label: '跳',
                onChanged: onJumpHeld,
                onInteract: onInteract,
                fill: MacaronColors.blush.withValues(alpha: 0.9),
                size: 78 * s,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RoundHold extends StatefulWidget {
  const _RoundHold({
    required this.onChanged,
    this.onInteract,
    this.icon,
    this.label,
    this.fill,
    this.size = 64,
  });

  final ValueChanged<bool> onChanged;
  final VoidCallback? onInteract;
  final IconData? icon;
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
          child: widget.icon != null
              ? Icon(widget.icon, color: MacaronColors.cocoa, size: 22)
              : Text(
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
