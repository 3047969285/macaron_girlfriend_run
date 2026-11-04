import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:macaron_girlfriend_run/theme/macaron_colors.dart';
import 'package:macaron_girlfriend_run/ui/game_viewport.dart';

/// 马卡龙风格结果弹窗
Future<T?> showMacaronDialog<T>({
  required BuildContext context,
  required String title,
  required String body,
  required List<MacaronDialogAction> actions,
  bool landscape = false,
  bool celebration = false,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'dialog',
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 220),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.96, end: 1).animate(curved),
          child: child,
        ),
      );
    },
    pageBuilder: (ctx, _, __) {
      final dialog = SafeArea(
        child: Center(
          child: Material(
            color: Colors.transparent,
            // 矮屏（横屏手机只有 ~375 高）上标题和按钮固定可见，只让正文滚动，
            // 避免主按钮被挤到折叠线以下。
            child: LayoutBuilder(
              builder: (context, constraints) {
                final verticalMargin = constraints.maxHeight < 480 ? 8.0 : 24.0;
                return Container(
                  width: 320,
                  constraints: BoxConstraints(
                    maxHeight: constraints.maxHeight - verticalMargin * 2,
                  ),
                  margin: EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: verticalMargin,
                  ),
                  padding: const EdgeInsets.fromLTRB(22, 22, 22, 16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFFF4F1F3),
                        Color(0xFFF1E4EA),
                        Color(0xFFE4EEEC),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
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
                      Flexible(
                        child: SingleChildScrollView(
                          child: celebration
                              ? CelebrationBody(body: body)
                              : Text(
                                  body,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    height: 1.45,
                                    color: MacaronColors.cocoa.withValues(
                                      alpha: 0.8,
                                    ),
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      for (final a in actions) ...[
                        SizedBox(
                          width: double.infinity,
                          child: CupertinoButton(
                            color: a.primary
                                ? MacaronColors.rose
                                : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            onPressed: () => a.onPressed(ctx),
                            child: Text(
                              a.label,
                              style: TextStyle(
                                color: a.primary
                                    ? Colors.white
                                    : MacaronColors.cocoa,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      );
      return landscape ? GameViewport(showHint: false, child: dialog) : dialog;
    },
  );
}

class CelebrationBody extends StatefulWidget {
  const CelebrationBody({super.key, required this.body});
  final String body;
  @override
  State<CelebrationBody> createState() => _CelebrationBodyState();
}

class _CelebrationBodyState extends State<CelebrationBody>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  )..forward();
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lines = widget.body.split('\n');
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final elapsed = _controller.value * 800;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < lines.length; i++)
              Opacity(
                opacity: ((elapsed - i * 100) / 100).clamp(0.0, 1.0),
                child: Text(
                  lines[i].replaceAllMapped(RegExp(r'分数\s+(\d+)'), (m) {
                    final score = int.parse(m[1]!);
                    return '分数 ${(score * Curves.easeOutCubic.transform(_controller.value)).round()}';
                  }),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    height: 1.45,
                    color: MacaronColors.cocoa.withValues(alpha: 0.8),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
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
void showAchievementToast(
  BuildContext context,
  String title, {
  String icon = '🎀',
  bool landscape = false,
}) {
  final overlay = Overlay.of(context);
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) {
      final toast = Builder(
        builder: (toastContext) => Stack(
          children: [
            Positioned(
              top: MediaQuery.paddingOf(toastContext).top + 16,
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6E5A7E), Color(0xFFA8344F)],
                      ),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x33000000),
                          blurRadius: 14,
                          offset: Offset(0, 6),
                        ),
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
            ),
          ],
        ),
      );
      return landscape ? GameViewport(showHint: false, child: toast) : toast;
    },
  );
  overlay.insert(entry);
  Future<void>.delayed(const Duration(milliseconds: 2400), () {
    entry.remove();
  });
}
