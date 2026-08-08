import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:macaron_girlfriend_run/theme/macaron_colors.dart';

/// 马卡龙风格结果弹窗
Future<T?> showMacaronDialog<T>({
  required BuildContext context,
  required String title,
  required String body,
  required List<MacaronDialogAction> actions,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'dialog',
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (ctx, _, __) {
      return Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 320,
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFFFF6F0),
                  Color(0xFFFFE8F0),
                  Color(0xFFE8FFF6),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 24,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: MacaronColors.cocoa,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  body,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    height: 1.45,
                    color: MacaronColors.cocoa.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: 18),
                for (final a in actions) ...[
                  SizedBox(
                    width: double.infinity,
                    child: CupertinoButton(
                      color: a.primary ? MacaronColors.rose : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      onPressed: () => a.onPressed(ctx),
                      child: Text(
                        a.label,
                        style: TextStyle(
                          color: a.primary ? Colors.white : MacaronColors.cocoa,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ],
            ),
          ),
        ),
      );
    },
  );
}

/// 弹窗按钮
class MacaronDialogAction {
  const MacaronDialogAction({
    required this.label,
    required this.onPressed,
    this.primary = false,
  });

  final String label;
  final void Function(BuildContext dialogContext) onPressed;
  final bool primary;
}

/// 顶部成就 Toast
void showAchievementToast(BuildContext context, String title, {String icon = '🎀'}) {
  final overlay = Overlay.of(context);
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) {
      return Positioned(
        top: MediaQuery.paddingOf(context).top + 16,
        left: 24,
        right: 24,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutBack,
          builder: (_, t, child) => Opacity(
            opacity: t.clamp(0.0, 1.0),
            child: Transform.translate(
              offset: Offset(0, (1 - t) * -16),
              child: child,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFB39DDB), Color(0xFFFFB4C8)],
                ),
                borderRadius: BorderRadius.circular(18),
                boxShadow: const [
                  BoxShadow(color: Color(0x33000000), blurRadius: 14, offset: Offset(0, 6)),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(icon, style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      '成就解锁 · $title',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
  overlay.insert(entry);
  Future<void>.delayed(const Duration(milliseconds: 2400), () {
    entry.remove();
  });
}
