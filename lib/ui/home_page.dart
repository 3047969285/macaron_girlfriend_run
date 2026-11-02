import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:macaron_girlfriend_run/data/audio_service.dart';
import 'package:macaron_girlfriend_run/data/game_models.dart';
import 'package:macaron_girlfriend_run/data/level_names.dart';
import 'package:macaron_girlfriend_run/data/save_service.dart';
import 'package:macaron_girlfriend_run/game/player/girlfriend_player.dart';
import 'package:macaron_girlfriend_run/theme/macaron_colors.dart';
import 'package:macaron_girlfriend_run/ui/controls.dart';
import 'package:macaron_girlfriend_run/ui/input_mode.dart';
import 'package:macaron_girlfriend_run/ui/macaron_dialogs.dart';
import 'package:macaron_girlfriend_run/ui/play_page.dart';
import 'package:macaron_girlfriend_run/ui/shop_page.dart';

/// 首页
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  void _refresh() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _open(Widget page) async {
    await AudioService.instance.click();
    if (!mounted) {
      return;
    }
    await Navigator.push(
      context,
      CupertinoPageRoute<void>(builder: (_) => page),
    );
    _refresh();
  }

  Future<void> _continue() async {
    await AudioService.instance.click();
    if (!mounted) {
      return;
    }
    final pos = SaveService.instance.continuePlayTarget();
    await Navigator.push(
      context,
      CupertinoPageRoute<void>(
        builder: (_) => PlayPage(
          worldIndex: pos.$1,
          levelIndex: pos.$2,
          origin: PlayOrigin.home,
        ),
      ),
    );
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final unlocked = SaveService.instance.unlockedGlobalIndex;
    final unlockedLevels = unlocked >= GameConstants.totalLevels
        ? GameConstants.totalLevels
        : unlocked + 1;
    final progress = (unlockedLevels / GameConstants.totalLevels).clamp(
      0.0,
      1.0,
    );

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final landscape = constraints.maxWidth >= constraints.maxHeight * 1.1;
          final menu = _HomeMenu(
            progress: progress,
            compact: constraints.maxHeight < 420,
            onContinue: _continue,
            onMap: () => _open(const WorldMapPage()),
            onShop: () => _open(const ShopPage()),
            onHow: () => _open(const HowToPlayPage()),
            onTasks: () => _open(const AchievementsPage()),
            onSettings: () => _open(const SettingsPage()),
          );
          final hero = _HeroFigure(
            role: SaveService.instance.playerRole,
            cosmeticId: SaveService.instance.equippedCosmeticId,
          );
          return Stack(
            fit: StackFit.expand,
            children: [
              const CustomPaint(painter: _HomeScenePainter()),
              SafeArea(
                child: landscape
                    ? Row(
                        children: [
                          Expanded(flex: 4, child: hero),
                          Expanded(
                            flex: 6,
                            child: Center(
                              child: SingleChildScrollView(
                                padding: const EdgeInsets.fromLTRB(8, 8, 28, 8),
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 420,
                                  ),
                                  child: menu,
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                    : Column(
                        children: [
                          Expanded(flex: 4, child: hero),
                          Expanded(
                            flex: 6,
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.fromLTRB(28, 4, 28, 20),
                              child: Center(
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 420,
                                  ),
                                  child: menu,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// 标题、进度条和六个入口：继续冒险最大，选关/商店次之，玩法/任务/设置最小。
class _HomeMenu extends StatelessWidget {
  const _HomeMenu({
    required this.progress,
    required this.compact,
    required this.onContinue,
    required this.onMap,
    required this.onShop,
    required this.onHow,
    required this.onTasks,
    required this.onSettings,
  });

  final double progress;
  final bool compact;
  final VoidCallback onContinue;
  final VoidCallback onMap;
  final VoidCallback onShop;
  final VoidCallback onHow;
  final VoidCallback onTasks;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final gap = compact ? 8.0 : 12.0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _OutlinedTitle('马卡龙女友跑酷', fontSize: compact ? 30 : 36),
        SizedBox(height: compact ? 8 : 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            backgroundColor: Colors.white.withValues(alpha: 0.7),
            color: MacaronColors.rose,
          ),
        ),
        SizedBox(height: compact ? 14 : 22),
        _MenuButton(
          label: '继续冒险',
          icon: CupertinoIcons.play_fill,
          height: compact ? 54 : 62,
          fontSize: compact ? 20 : 22,
          primary: true,
          onTap: onContinue,
        ),
        SizedBox(height: gap),
        Row(
          children: [
            Expanded(
              child: _MenuButton(
                label: '选关地图',
                icon: CupertinoIcons.map_fill,
                height: compact ? 44 : 50,
                onTap: onMap,
              ),
            ),
            SizedBox(width: gap),
            Expanded(
              child: _MenuButton(
                label: '糖果商店',
                icon: CupertinoIcons.bag_fill,
                height: compact ? 44 : 50,
                onTap: onShop,
              ),
            ),
          ],
        ),
        SizedBox(height: gap),
        Row(
          children: [
            Expanded(
              child: _MenuButton(
                label: '玩法',
                icon: CupertinoIcons.question_circle_fill,
                height: compact ? 38 : 42,
                fontSize: 14,
                subtle: true,
                onTap: onHow,
              ),
            ),
            SizedBox(width: gap),
            Expanded(
              child: _MenuButton(
                label: '任务',
                icon: CupertinoIcons.star_fill,
                height: compact ? 38 : 42,
                fontSize: 14,
                subtle: true,
                onTap: onTasks,
              ),
            ),
            SizedBox(width: gap),
            Expanded(
              child: _MenuButton(
                label: '设置',
                icon: CupertinoIcons.gear_solid,
                height: compact ? 38 : 42,
                fontSize: 14,
                subtle: true,
                onTap: onSettings,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// 白色描边加可可色填充的标题字，压在任何背景上都清楚。
class _OutlinedTitle extends StatelessWidget {
  const _OutlinedTitle(this.text, {required this.fontSize});

  final String text;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final base = TextStyle(
      fontSize: fontSize,
      fontWeight: FontWeight.w900,
      letterSpacing: 2,
    );
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Stack(
        children: [
          Text(
            text,
            style: base.copyWith(
              foreground: Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 7
                ..strokeJoin = StrokeJoin.round
                ..color = Colors.white,
              shadows: const [
                Shadow(
                  color: Color(0x33FF6F9C),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
          ),
          Text(text, style: base.copyWith(color: const Color(0xFFE0507E))),
        ],
      ),
    );
  }
}

/// 首页按钮：主按钮粉色渐变，次级白色玻璃，最小的一排半透明。
class _MenuButton extends StatelessWidget {
  const _MenuButton({
    required this.label,
    required this.icon,
    required this.height,
    required this.onTap,
    this.fontSize = 17,
    this.primary = false,
    this.subtle = false,
  });

  final String label;
  final IconData icon;
  final double height;
  final double fontSize;
  final bool primary;
  final bool subtle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textColor = primary ? Colors.white : MacaronColors.cocoa;
    final decoration = BoxDecoration(
      borderRadius: BorderRadius.circular(height / 2),
      gradient: primary
          ? const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFFF9EBD), Color(0xFFFF6F9C)],
            )
          : null,
      color: primary
          ? null
          : Colors.white.withValues(alpha: subtle ? 0.55 : 0.88),
      border: Border.all(
        color: Colors.white.withValues(alpha: primary ? 0.9 : 0.7),
        width: 2,
      ),
      boxShadow: [
        BoxShadow(
          color: (primary ? const Color(0xFFFF6F9C) : const Color(0xFF8E6A7A))
              .withValues(alpha: primary ? 0.38 : 0.14),
          blurRadius: primary ? 18 : 10,
          offset: Offset(0, primary ? 7 : 4),
        ),
      ],
    );
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      onPressed: onTap,
      child: Container(
        height: height,
        alignment: Alignment.center,
        decoration: decoration,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: fontSize + 1,
              color: primary ? Colors.white : const Color(0xFFE0507E),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w800,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 首页主角：站在草地上的静态立绘（只眨眼，不乱动）。
class _HeroFigure extends StatefulWidget {
  const _HeroFigure({required this.role, required this.cosmeticId});

  final PlayerRole role;
  final String cosmeticId;

  @override
  State<_HeroFigure> createState() => _HeroFigureState();
}

class _HeroFigureState extends State<_HeroFigure> {
  late final GirlfriendPlayer _player;

  @override
  void initState() {
    super.initState();
    _player = GirlfriendPlayer(role: widget.role, cosmeticId: widget.cosmeticId)
      ..onGround = true;
    // 先走到一个睁眼的时刻；立绘之后不再更新，所以不会乱动。
    _player.update(0.6);
  }

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _HeroPainter(_player),
    child: const SizedBox.expand(),
  );
}

class _HeroPainter extends CustomPainter {
  _HeroPainter(this.player);

  final GirlfriendPlayer player;

  @override
  void paint(Canvas canvas, Size size) {
    // 立绘高度占可用高度的 62%，脚踩在草地上沿略下方。
    final target = size.height * 0.62;
    final k = target / player.size.y;
    final feet = Offset(size.width * 0.5, size.height * 0.9);
    canvas.save();
    canvas.translate(feet.dx, feet.dy);
    canvas.scale(k);
    canvas.translate(-player.size.x / 2, -player.size.y);
    player.render(canvas);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_HeroPainter oldDelegate) => false;
}

/// 首页背景：粉到奶油到薄荷的天空，云、远山、近丘、草地和漂浮的马卡龙。
class _HomeScenePainter extends CustomPainter {
  const _HomeScenePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFC2D9), Color(0xFFFFE9E0), Color(0xFFD3F5E6)],
          stops: [0.0, 0.55, 1.0],
        ).createShader(Offset.zero & size),
    );
    // 柔和的日光。
    canvas.drawCircle(
      Offset(w * 0.82, h * 0.16),
      h * 0.32,
      Paint()
        ..shader =
            RadialGradient(
              colors: [
                Colors.white.withValues(alpha: 0.75),
                Colors.white.withValues(alpha: 0),
              ],
            ).createShader(
              Rect.fromCircle(
                center: Offset(w * 0.82, h * 0.16),
                radius: h * 0.32,
              ),
            ),
    );

    void cloud(double cx, double cy, double s) {
      final paint = Paint()..color = Colors.white.withValues(alpha: 0.82);
      for (final (dx, dy, r) in const [
        (-1.0, 0.1, 0.55),
        (-0.35, -0.2, 0.75),
        (0.45, -0.05, 0.65),
        (1.05, 0.12, 0.5),
      ]) {
        canvas.drawCircle(Offset(cx + dx * s, cy + dy * s), r * s, paint);
      }
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(
            cx - 1.4 * s,
            cy + 0.1 * s,
            cx + 1.45 * s,
            cy + 0.62 * s,
          ),
          Radius.circular(0.3 * s),
        ),
        paint,
      );
    }

    cloud(w * 0.14, h * 0.2, h * 0.075);
    cloud(w * 0.55, h * 0.12, h * 0.06);
    cloud(w * 0.9, h * 0.36, h * 0.05);

    Path hills(double base, double amp, double freq, double phase) {
      final p = Path()..moveTo(0, h);
      for (var x = 0.0; x <= w; x += 6) {
        final y =
            base +
            amp * math.sin(x / w * freq * math.pi * 2 + phase) +
            amp * 0.4 * math.sin(x / w * freq * 5.1 + phase * 1.7);
        p.lineTo(x, y);
      }
      return p
        ..lineTo(w, h)
        ..close();
    }

    canvas.drawPath(
      hills(h * 0.62, h * 0.05, 1.1, 0.4),
      Paint()..color = const Color(0xFFFFD3E3),
    );
    canvas.drawPath(
      hills(h * 0.7, h * 0.045, 1.6, 2.0),
      Paint()..color = const Color(0xFFC4EFD9),
    );
    canvas.drawPath(
      hills(h * 0.8, h * 0.03, 1.3, 1.1),
      Paint()..color = const Color(0xFFA6E6C5),
    );
    // 近处草地，上沿是一排圆润的草丛。
    final ground = Path()
      ..moveTo(0, h * 0.88)
      ..lineTo(w, h * 0.88)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(ground, Paint()..color = const Color(0xFF8FDDB3));
    final tuft = Paint()..color = const Color(0xFF8FDDB3);
    for (var x = 0.0; x < w; x += h * 0.07) {
      canvas.drawCircle(Offset(x, h * 0.885), h * 0.04, tuft);
    }
    canvas.drawRect(
      Rect.fromLTWH(0, h * 0.93, w, h * 0.07),
      Paint()..color = const Color(0xFF7ACFA1),
    );

    // 漂浮的马卡龙和糖粒，只是装饰，不动。
    void macaron(double cx, double cy, double r, Color a, Color b) {
      final top = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(cx, cy - r * 0.32),
          width: r * 2,
          height: r * 0.9,
        ),
        Radius.circular(r * 0.6),
      );
      final bottom = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(cx, cy + r * 0.32),
          width: r * 2,
          height: r * 0.9,
        ),
        Radius.circular(r * 0.6),
      );
      canvas.drawRRect(bottom, Paint()..color = b);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(cx, cy),
            width: r * 1.8,
            height: r * 0.36,
          ),
          Radius.circular(r * 0.18),
        ),
        Paint()..color = const Color(0xFFFFF6E8),
      );
      canvas.drawRRect(top, Paint()..color = a);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(cx - r * 0.45, cy - r * 0.5),
          width: r * 0.5,
          height: r * 0.2,
        ),
        Paint()..color = Colors.white.withValues(alpha: 0.55),
      );
    }

    macaron(
      w * 0.07,
      h * 0.52,
      h * 0.035,
      const Color(0xFFFFB3CE),
      const Color(0xFFFF9EBD),
    );
    macaron(
      w * 0.36,
      h * 0.3,
      h * 0.03,
      const Color(0xFFBFEBD8),
      const Color(0xFFA3DFC4),
    );
    macaron(
      w * 0.93,
      h * 0.6,
      h * 0.04,
      const Color(0xFFD8C8F5),
      const Color(0xFFC2AEEB),
    );
    macaron(
      w * 0.62,
      h * 0.07,
      h * 0.028,
      const Color(0xFFFFE08A),
      const Color(0xFFFFD25E),
    );
    final sprinkle = [
      const Color(0xFFFF9EBD),
      const Color(0xFFBFEBD8),
      const Color(0xFFD8C8F5),
      const Color(0xFFFFE08A),
    ];
    for (var i = 0; i < 26; i++) {
      final fx = (math.sin(i * 12.9898) * 43758.5453) % 1;
      final fy = (math.sin(i * 78.233) * 12345.6789) % 1;
      canvas.drawCircle(
        Offset(w * fx.abs(), h * 0.05 + h * 0.55 * fy.abs()),
        h * 0.006,
        Paint()..color = sprinkle[i % 4].withValues(alpha: 0.8),
      );
    }
  }

  @override
  bool shouldRepaint(_HomeScenePainter oldDelegate) => false;
}

/// 九大世界选关
class WorldMapPage extends StatefulWidget {
  const WorldMapPage({super.key, this.initialWorld = 0});

  /// 超出 0..worldCount-1 时夹紧。
  final int initialWorld;

  @override
  State<WorldMapPage> createState() => _WorldMapPageState();
}

class _WorldMapPageState extends State<WorldMapPage> {
  late int world;

  int _clampWorld(int index) => index.clamp(0, GameConstants.worldCount - 1);

  @override
  void initState() {
    super.initState();
    world = _clampWorld(widget.initialWorld);
  }

  @override
  void didUpdateWidget(covariant WorldMapPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialWorld != widget.initialWorld) {
      world = _clampWorld(widget.initialWorld);
    }
  }

  Future<void> _openLevel(int level) async {
    await AudioService.instance.click();
    if (!mounted) {
      return;
    }
    final name = LevelNames.of(world, level);
    final global = SaveService.toGlobal(world, level);
    final stars = SaveService.instance.starsOf(global);
    final best = SaveService.instance.bestScoreOf(global);
    final isBoss = level == GameConstants.levelsPerWorld - 1;
    final starLine = stars > 0
        ? '历史最高 ${List.filled(stars, '★').join()} · 纪录 $best'
        : '尚未通关 · 冲一颗星试试';
    await showMacaronDialog<void>(
      context: context,
      title: isBoss ? 'Boss 关预览' : '关卡预览',
      body:
          '${WorldCatalog.paletteOf(world).name}\n'
          '$name\n'
          '$starLine\n'
          '${isBoss ? '先踩扁 Boss 才能摸旗\n' : ''}'
          '进关后可暂停查看三星条件',
      actions: [
        MacaronDialogAction(
          label: '再逛逛',
          onPressed: (ctx) => Navigator.pop(ctx),
        ),
        MacaronDialogAction(
          label: '开始',
          primary: true,
          onPressed: (ctx) {
            Navigator.pop(ctx);
            Navigator.push(
              context,
              CupertinoPageRoute<void>(
                builder: (_) => PlayPage(worldIndex: world, levelIndex: level),
              ),
            ).then((_) {
              if (mounted) {
                setState(() {});
              }
            });
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final unlocked = SaveService.instance.unlockedGlobalIndex;
    final palette = WorldCatalog.paletteOf(world);
    return Scaffold(
      backgroundColor: MacaronColors.cream,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 16, 0),
              child: Row(
                children: [
                  CupertinoButton(
                    padding: const EdgeInsets.all(8),
                    onPressed: () => Navigator.pop(context),
                    child: const Icon(
                      CupertinoIcons.back,
                      color: MacaronColors.cocoa,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      '${palette.name} · 选关',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: MacaronColors.cocoa,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: GameConstants.worldCount,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final selected = i == world;
                  return GestureDetector(
                    onTap: () => setState(() => world = i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: selected ? MacaronColors.blush : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        WorldCatalog.paletteOf(i).name,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: selected ? Colors.white : MacaronColors.cocoa,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.2,
                ),
                itemCount: GameConstants.levelsPerWorld,
                itemBuilder: (_, level) {
                  final global = SaveService.toGlobal(world, level);
                  final locked = global > unlocked;
                  final stars = SaveService.instance.starsOf(global);
                  final best = SaveService.instance.bestScoreOf(global);
                  final name = LevelNames.of(world, level);
                  return GestureDetector(
                    onTap: locked ? null : () => _openLevel(level),
                    child: Opacity(
                      opacity: locked ? 0.4 : 1,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Color.lerp(palette.ground, Colors.white, 0.45)!,
                              Colors.white,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: palette.accent.withValues(alpha: 0.35),
                          ),
                        ),
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              locked ? '🔒' : '${level + 1}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: MacaronColors.cocoa,
                              ),
                            ),
                            if (!locked) ...[
                              Text(
                                name,
                                maxLines: 2,
                                textAlign: TextAlign.center,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: MacaronColors.cocoa,
                                ),
                              ),
                              if (stars > 0)
                                Text(
                                  List.filled(stars, '★').join(),
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: MacaronColors.rose,
                                  ),
                                ),
                              if (best > 0)
                                Text(
                                  '纪录 $best',
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: MacaronColors.cocoa.withValues(
                                      alpha: 0.45,
                                    ),
                                  ),
                                ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 玩法说明
class HowToPlayPage extends StatelessWidget {
  const HowToPlayPage({super.key});

  @override
  Widget build(BuildContext context) {
    return _SimplePage(
      title: '玩法说明',
      children: [
        _TipCard(
          emoji: '🎯',
          title: '本关目标',
          body: '限时内跑到旗杆通关。第 11 关是 Boss 关，需先踩扁大 Boss 才能摸旗。',
        ),
        SizedBox(height: 10),
        _TipCard(
          emoji: '🕹️',
          title: '操作',
          body:
              '触控：${InputModeRules.touchLines.join(' · ')}\n'
              '键盘：${InputModeRules.keyboardLines.join(' · ')}',
        ),
        SizedBox(height: 10),
        _TipCard(
          emoji: '🏳️',
          title: '检查点与敌人',
          body:
              '蓝色小旗：摸到后本局复活点前移。\n'
              '看头顶预警：粉怪射糖可蹲躲、橙怪扑击、红胖冲撞、薄荷怪设陷阱、蓝飞怪俯冲。\n'
              '红胖和糖壳要踩两次；滚轮平时就快，糖泡会整只弹起再落下。Boss 半血狂暴并跳砸。',
        ),
        SizedBox(height: 10),
        _TipCard(
          emoji: '❓',
          title: '机关与商店',
          body:
              '顶「?」砖：糖 / 超级跳 / 积分糖特效。\n'
              '天空三色台：蓝虚线从下面跳得穿、黄台站久会塌、紫台会带着人左右走。\n'
              '关卡糖果进钱包，首页「糖果商店」可换外观。',
        ),
        SizedBox(height: 10),
        _TipCard(
          emoji: '⭐',
          title: '评分与生命',
          body:
              '通关 1 星；收集约 58% 以上 2 星；约 88% 且剩余 45 秒以上 3 星。\n开局 3 命，检查点只在本局有效。',
        ),
      ],
    );
  }
}

class _TipCard extends StatelessWidget {
  const _TipCard({
    required this.emoji,
    required this.title,
    required this.body,
  });

  final String emoji;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.white, MacaronColors.blush.withValues(alpha: 0.25)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 26)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: MacaronColors.cocoa,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.35,
                    color: MacaronColors.cocoa.withValues(alpha: 0.72),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 成就页
class AchievementsPage extends StatelessWidget {
  const AchievementsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final list = SaveService.instance.achievements();
    final done = list.where((e) => e.unlocked).length;
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFE8F0), MacaronColors.cream, Color(0xFFE8FFF6)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _pageHeader(context, '甜蜜任务'),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      const Text('🎀', style: TextStyle(fontSize: 22)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '已完成 $done / ${list.length} 项甜蜜挑战',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: MacaronColors.cocoa,
                          ),
                        ),
                      ),
                      Text(
                        '${((done / list.length) * 100).round()}%',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: MacaronColors.rose,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, i) {
                    final a = list[i];
                    return _AchievementCard(item: a);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AchievementCard extends StatelessWidget {
  const _AchievementCard({required this.item});

  final AchievementItem item;

  @override
  Widget build(BuildContext context) {
    final unlocked = item.unlocked;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: unlocked
              ? [Colors.white, MacaronColors.lemon.withValues(alpha: 0.35)]
              : [
                  Colors.white.withValues(alpha: 0.92),
                  MacaronColors.blush.withValues(alpha: 0.12),
                ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: unlocked
              ? MacaronColors.rose.withValues(alpha: 0.55)
              : Colors.white,
          width: 1.4,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 14,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: unlocked
                  ? MacaronColors.rose.withValues(alpha: 0.18)
                  : Colors.black.withValues(alpha: 0.05),
            ),
            child: Text(
              unlocked ? item.icon : '🔒',
              style: const TextStyle(fontSize: 26),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.title,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: unlocked
                              ? MacaronColors.cocoa
                              : MacaronColors.cocoa.withValues(alpha: 0.75),
                        ),
                      ),
                    ),
                    if (unlocked)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: MacaronColors.rose,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          '完成',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  item.desc,
                  style: TextStyle(
                    color: MacaronColors.cocoa.withValues(alpha: 0.58),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: item.ratio,
                    minHeight: 8,
                    color: unlocked ? MacaronColors.mint : MacaronColors.rose,
                    backgroundColor: MacaronColors.blush.withValues(
                      alpha: 0.28,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '${item.progress} / ${item.target}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: MacaronColors.cocoa.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 关于页
class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return _SimplePage(
      title: '关于',
      children: const [
        Text(
          '马卡龙女友跑酷',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
        ),
        Text('版本 1.5.0 · 完全体'),
        SizedBox(height: 10),
        Text(
          '原创甜蜜平台跳跃单机。99 关、真暂停、Boss 血条、检查点、狂暴 Boss、'
          '耐打红胖怪、糖果商店、真拖尾外观、视差、分世界 BGM、键盘操作、'
          '关卡预览与通关仪式、本地存档，无联网无广告。'
          '已优化继续冒险、粘键、超时续时、问号砖三星、触控反馈、'
          '相机前瞻、长关性能与 iPhone 网页加载。',
        ),
        SizedBox(height: 10),
        Text('隐私：进度仅保存在本机，无账号、无联网、无广告追踪。'),
        SizedBox(height: 10),
        Text('适龄提示：休闲益智，建议 4+。'),
      ],
    );
  }
}

/// 设置页
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

/// 音量滑块规则：开关关时显示 0；拖到 0 即关，大于 0 即开。
class AudioSliderRules {
  AudioSliderRules._();

  /// enabled 为 false 时返回 0，否则返回 volume。
  static double display({required bool enabled, required double volume}) =>
      enabled ? volume : 0;

  /// 返回新的开关和音量：(enabled: value > 0, volume: value)。
  static ({bool enabled, double volume}) apply(double value) =>
      (enabled: value > 0, volume: value);
}

class _SettingsPageState extends State<SettingsPage> {
  late int fpsMode;
  late PlayerRole role;
  late bool sound;
  late bool music;
  late bool haptic;
  late double soundVol;
  late double musicVol;
  late double controlScale;

  @override
  void initState() {
    super.initState();
    fpsMode = SaveService.instance.fpsMode;
    role = SaveService.instance.playerRole;
    sound = SaveService.instance.soundEnabled;
    music = SaveService.instance.musicEnabled;
    haptic = SaveService.instance.hapticEnabled;
    soundVol = SaveService.instance.soundVolume;
    musicVol = SaveService.instance.musicVolume;
    controlScale = SaveService.instance.controlScale;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MacaronColors.cream,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            _pageHeader(context, '设置'),
            _section('音效与触感'),
            ListTile(
              title: const Text('音效音量'),
              subtitle: Slider(
                value: AudioSliderRules.display(
                  enabled: sound,
                  volume: soundVol,
                ),
                activeColor: MacaronColors.rose,
                onChanged: (v) async {
                  final r = AudioSliderRules.apply(v);
                  setState(() {
                    sound = r.enabled;
                    soundVol = r.volume;
                  });
                  await SaveService.instance.setSoundEnabled(r.enabled);
                  await SaveService.instance.setSoundVolume(r.volume);
                  await AudioService.instance.applyVolumes();
                },
              ),
            ),
            ListTile(
              title: const Text('音乐音量'),
              subtitle: Slider(
                value: AudioSliderRules.display(
                  enabled: music,
                  volume: musicVol,
                ),
                activeColor: MacaronColors.lilac,
                onChanged: (v) async {
                  final r = AudioSliderRules.apply(v);
                  final wasAudible = music && musicVol > 0;
                  setState(() {
                    music = r.enabled;
                    musicVol = r.volume;
                  });
                  await SaveService.instance.setMusicEnabled(r.enabled);
                  await SaveService.instance.setMusicVolume(r.volume);
                  await AudioService.instance.applyVolumes();
                  if (wasAudible && !r.enabled) {
                    // ignore: unawaited_futures
                    AudioService.instance.stopBgm();
                  } else if (!wasAudible && r.enabled) {
                    // ignore: unawaited_futures
                    AudioService.instance.resumeBgm();
                  }
                },
              ),
            ),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              leading: const Icon(CupertinoIcons.music_note_2),
              title: const Text('音乐来源与授权'),
              subtitle: const Text('Kevin MacLeod · CC BY 4.0'),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              children: const [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Slow Jam — Kevin MacLeod\n'
                    'https://incompetech.com/music/royalty-free/index.html?isrc=USUAN1600015',
                  ),
                ),
                SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Smooth Lovin — Kevin MacLeod\n'
                    'https://incompetech.com/music/royalty-free/index.html?isrc=USUAN1700077',
                  ),
                ),
                SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Morning — Kevin MacLeod\n'
                    'https://incompetech.com/music/royalty-free/index.html?isrc=USUAN2300003',
                  ),
                ),
                SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '普通关按世界轮换播放这三首授权音乐；Boss 关使用每个世界的原创短曲。\n'
                    '音频资源不可用时会自动切换备用曲。\n'
                    '许可：Creative Commons Attribution 4.0 International\n'
                    'https://creativecommons.org/licenses/by/4.0/',
                  ),
                ),
              ],
            ),
            SwitchListTile(
              title: const Text('震动反馈'),
              value: haptic,
              activeThumbColor: MacaronColors.rose,
              onChanged: (v) async {
                setState(() => haptic = v);
                await SaveService.instance.setHapticEnabled(v);
              },
            ),
            _section('触控'),
            ListTile(
              title: const Text('按钮大小'),
              subtitle: Slider(
                value: controlScale,
                min: 0.85,
                max: 1.25,
                divisions: 8,
                label: controlScale.toStringAsFixed(2),
                activeColor: MacaronColors.mint,
                onChanged: (v) async {
                  setState(() => controlScale = v);
                  await SaveService.instance.setControlScale(v);
                },
              ),
            ),
            if (FpsBootstrap.isSupported) ...[
              _section('帧率'),
              Wrap(
                spacing: 8,
                children: [
                  for (final e in const [
                    (0, '自动'),
                    (1, '60'),
                    (2, '90'),
                    (3, '120'),
                  ])
                    ChoiceChip(
                      label: Text(e.$2),
                      selected: fpsMode == e.$1,
                      selectedColor: MacaronColors.blush,
                      onSelected: (_) async {
                        setState(() => fpsMode = e.$1);
                        await SaveService.instance.setFpsMode(e.$1);
                        await FpsBootstrap.applyMode(e.$1);
                      },
                    ),
                ],
              ),
              const SizedBox(height: 16),
            ],
            _section('角色外观'),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('女友'),
                  selected: role == PlayerRole.girlfriend,
                  selectedColor: MacaronColors.blush,
                  onSelected: (_) async {
                    setState(() => role = PlayerRole.girlfriend);
                    await SaveService.instance.setPlayerRole(
                      PlayerRole.girlfriend,
                    );
                  },
                ),
                ChoiceChip(
                  label: const Text('男友'),
                  selected: role == PlayerRole.boyfriend,
                  selectedColor: MacaronColors.sky,
                  onSelected: (_) async {
                    setState(() => role = PlayerRole.boyfriend);
                    await SaveService.instance.setPlayerRole(
                      PlayerRole.boyfriend,
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              '更多装扮请去首页「糖果商店」',
              style: TextStyle(fontSize: 12, color: MacaronColors.cocoa),
            ),
            const SizedBox(height: 16),
            _section('教程与存档'),
            ListTile(
              title: const Text('重看新手教程'),
              subtitle: const Text('下次进关卡时再次显示'),
              trailing: const Icon(CupertinoIcons.refresh),
              onTap: () async {
                await SaveService.instance.resetTutorial();
                if (!context.mounted) {
                  return;
                }
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('已重置教程，下次进关会再出现')));
              },
            ),
            ListTile(
              title: const Text('清除游戏进度'),
              subtitle: const Text('星级、解锁、钱包与外观购买会清空'),
              trailing: const Icon(
                CupertinoIcons.trash,
                color: MacaronColors.rose,
              ),
              onTap: () async {
                final ok = await showCupertinoDialog<bool>(
                  context: context,
                  builder: (ctx) => CupertinoAlertDialog(
                    title: const Text('确认清档？'),
                    content: const Text('此操作不可撤销，音量与帧率设置会保留'),
                    actions: [
                      CupertinoDialogAction(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('取消'),
                      ),
                      CupertinoDialogAction(
                        isDestructiveAction: true,
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('清除'),
                      ),
                    ],
                  ),
                );
                if (ok == true) {
                  await SaveService.instance.resetProgress();
                  if (context.mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(const SnackBar(content: Text('进度已清除')));
                  }
                }
              },
            ),
            ListTile(
              title: const Text('关于'),
              trailing: const Icon(CupertinoIcons.info),
              onTap: () => Navigator.push(
                context,
                CupertinoPageRoute<void>(builder: (_) => const AboutPage()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(String t) => Padding(
    padding: const EdgeInsets.only(top: 8, bottom: 8),
    child: Text(
      t,
      style: TextStyle(
        fontWeight: FontWeight.w700,
        color: MacaronColors.cocoa.withValues(alpha: 0.55),
      ),
    ),
  );
}

class _SimplePage extends StatelessWidget {
  const _SimplePage({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MacaronColors.cream,
      body: SafeArea(
        child: Column(
          children: [
            _pageHeader(context, title),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  for (final c in children) ...[
                    DefaultTextStyle(
                      style: const TextStyle(
                        color: MacaronColors.cocoa,
                        height: 1.45,
                        fontSize: 14,
                      ),
                      child: c,
                    ),
                    const SizedBox(height: 4),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _pageHeader(BuildContext context, String title) {
  return Padding(
    padding: const EdgeInsets.fromLTRB(8, 4, 16, 8),
    child: Row(
      children: [
        CupertinoButton(
          padding: const EdgeInsets.all(8),
          onPressed: () => Navigator.pop(context),
          child: const Icon(CupertinoIcons.back, color: MacaronColors.cocoa),
        ),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: MacaronColors.cocoa,
          ),
        ),
      ],
    ),
  );
}
