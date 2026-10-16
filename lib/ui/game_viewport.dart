import 'package:flutter/material.dart';
import 'package:macaron_girlfriend_run/theme/macaron_colors.dart';

/// 竖屏宿主内仍提供完整横屏坐标；同一棵子树跨尺寸变化保留游戏状态。
class GameViewport extends StatefulWidget {
  const GameViewport({
    super.key,
    required this.child,
    this.showHint = true,
    this.onGeometryChanged,
  });

  final Widget child;
  final bool showHint;
  final VoidCallback? onGeometryChanged;

  @override
  State<GameViewport> createState() => _GameViewportState();
}

class _GameViewportState extends State<GameViewport> {
  (Size, EdgeInsets)? _geometry;

  EdgeInsets _rotateInsets(EdgeInsets value) =>
      EdgeInsets.fromLTRB(value.top, value.right, value.bottom, value.left);

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final portrait = constraints.maxWidth < constraints.maxHeight;
      final media = MediaQuery.of(context);
      final geometry = (constraints.biggest, media.padding);
      if (_geometry != geometry) {
        if (_geometry != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) widget.onGeometryChanged?.call();
          });
        }
        _geometry = geometry;
      }
      final logicalMedia = portrait
          ? media.copyWith(
              size: Size(constraints.maxHeight, constraints.maxWidth),
              padding: _rotateInsets(media.padding),
              viewPadding: _rotateInsets(media.viewPadding),
              viewInsets: _rotateInsets(media.viewInsets),
            )
          : media;
      return Stack(
        fit: StackFit.expand,
        children: [
          RotatedBox(
            quarterTurns: portrait ? 1 : 0,
            child: MediaQuery(data: logicalMedia, child: widget.child),
          ),
          if (portrait && widget.showHint)
            Positioned(
              top: media.padding.top + 8,
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: Center(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: MacaronColors.cream.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      child: Text(
                        '横置手机或加宽窗口',
                        style: TextStyle(
                          fontSize: 11,
                          color: MacaronColors.cocoa,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
    },
  );
}
