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
  });

  final ValueChanged<bool> onLeft;
  final ValueChanged<bool> onRight;
  final ValueChanged<bool> onRun;
  final ValueChanged<bool> onJumpHeld;
  final ValueChanged<bool>? onDuck;

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
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
              ),
              const SizedBox(width: 14),
              _RoundHold(
                icon: CupertinoIcons.right_chevron,
                onChanged: onRight,
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
                  fill: MacaronColors.lilac.withValues(alpha: 0.85),
                  size: 62,
                ),
                const SizedBox(width: 12),
              ],
              _RoundHold(
                label: '跑',
                onChanged: onRun,
                fill: MacaronColors.mint.withValues(alpha: 0.85),
              ),
              const SizedBox(width: 14),
              _RoundHold(
                label: '跳',
                onChanged: onJumpHeld,
                fill: MacaronColors.blush.withValues(alpha: 0.9),
                size: 78,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RoundHold extends StatelessWidget {
  const _RoundHold({
    required this.onChanged,
    this.icon,
    this.label,
    this.fill,
    this.size = 64,
  });

  final ValueChanged<bool> onChanged;
  final IconData? icon;
  final String? label;
  final Color? fill;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (_) => onChanged(true),
      onPointerUp: (_) => onChanged(false),
      onPointerCancel: (_) => onChanged(false),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: fill ?? Colors.white.withValues(alpha: 0.7),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.65)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x18000000),
              blurRadius: 16,
              offset: Offset(0, 6),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: icon != null
            ? Icon(icon, color: MacaronColors.cocoa, size: 22)
            : Text(
                label ?? '',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: MacaronColors.cocoa,
                ),
              ),
      ),
    );
  }
}
