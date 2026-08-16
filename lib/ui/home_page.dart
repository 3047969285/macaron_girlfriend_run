import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:macaron_girlfriend_run/data/audio_service.dart';
import 'package:macaron_girlfriend_run/data/game_models.dart';
import 'package:macaron_girlfriend_run/data/level_names.dart';
import 'package:macaron_girlfriend_run/data/save_service.dart';
import 'package:macaron_girlfriend_run/theme/macaron_colors.dart';
import 'package:macaron_girlfriend_run/ui/controls.dart';
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

  @override
  Widget build(BuildContext context) {
    final unlocked = SaveService.instance.unlockedGlobalIndex;
    final cont = SaveService.instance.continuePlayTarget();
    final progress =
        (unlocked / GameConstants.totalLevels).clamp(0.0, 1.0).toDouble();

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFFFE8F0),
              MacaronColors.cream,
              Color(0xFFE8FFF6),
              Color(0xFFD6F0FF),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 16),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  const Text(
                    '马卡龙女友跑酷',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                      color: MacaronColors.cocoa,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '99 关最好玩完整版 · Boss 狂暴 / 检查点 / 商店',
                    style: TextStyle(
                      fontSize: 13,
                      color: MacaronColors.cocoa.withValues(alpha: 0.55),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '累计 ${SaveService.instance.totalStars} 星 · '
                    '${SaveService.instance.clearCount} 通关 · '
                    '最高分 ${SaveService.instance.bestScoreOverall} · '
                    '钱包 🍬${SaveService.instance.walletCoins}',
                    style: TextStyle(
                      fontSize: 12,
                      color: MacaronColors.cocoa.withValues(alpha: 0.45),
                    ),
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 8,
                      backgroundColor: Colors.white54,
                      color: MacaronColors.rose,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '进度 ${(progress * 100).toStringAsFixed(0)}% · '
                    '${unlocked.clamp(0, GameConstants.totalLevels)}/'
                    '${GameConstants.totalLevels}',
                    style: TextStyle(
                      fontSize: 11,
                      color: MacaronColors.cocoa.withValues(alpha: 0.4),
                    ),
                  ),
                  const SizedBox(height: 28),
                  _PillButton(
                    label: '继续冒险',
                    subtitle: unlocked == 0
                        ? '从第 1 关开始'
                        : '${WorldCatalog.paletteOf(cont.$1).name} · '
                            '${LevelNames.of(cont.$1, cont.$2)}',
                    filled: true,
                    onTap: () async {
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
                          ),
                        ),
                      );
                      _refresh();
                    },
                  ),
                  const SizedBox(height: 12),
                  _PillButton(
                    label: '选关地图',
                    onTap: () => _open(const WorldMapPage()),
                  ),
                  const SizedBox(height: 12),
                  _PillButton(
                    label: '糖果商店',
                    subtitle: '兑换蝴蝶结 / 皇冠等外观',
                    onTap: () => _open(const ShopPage()),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _PillButton(
                          label: '玩法',
                          compact: true,
                          onTap: () => _open(const HowToPlayPage()),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _PillButton(
                          label: '任务',
                          compact: true,
                          onTap: () => _open(const AchievementsPage()),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _PillButton(
                          label: '设置',
                          compact: true,
                          onTap: () => _open(const SettingsPage()),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _PillButton(
                    label: 'iPhone 版',
                    subtitle: 'Safari 网页 / 添加到主屏幕',
                    onTap: () {
                      showCupertinoDialog<void>(
                        context: context,
                        builder: (ctx) => CupertinoAlertDialog(
                          title: const Text('iPhone 怎么玩'),
                          content: const Text(
                            '不必同 Wi-Fi，可以部署到公网：\n\n'
                            '① 最快：运行「部署iPhone公网.bat」→ 打开 netlify.com/drop → '
                            '拖入桌面「马卡龙-iPhone网页版」→ 得到 netlify.app 链接\n\n'
                            '② 永久：工程推 GitHub → Pages 开 GitHub Actions\n\n'
                            '③ 同 Wi-Fi：运行「给iPhone玩.bat」\n\n'
                            'Safari 打开 → 分享 → 添加到主屏幕',
                          ),
                          actions: [
                            CupertinoDialogAction(
                              isDefaultAction: true,
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('知道了'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => _open(const AboutPage()),
                    child: const Text('关于与上架说明'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  const _PillButton({
    required this.label,
    required this.onTap,
    this.subtitle,
    this.filled = false,
    this.compact = false,
  });

  final String label;
  final String? subtitle;
  final bool filled;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: compact ? null : double.infinity,
      height: subtitle == null ? 48 : 64,
      child: CupertinoButton(
        padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 16),
        borderRadius: BorderRadius.circular(22),
        color: filled ? MacaronColors.rose : Colors.white.withValues(alpha: 0.82),
        onPressed: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: compact ? 14 : 17,
                fontWeight: FontWeight.w700,
                color: filled ? Colors.white : MacaronColors.cocoa,
              ),
            ),
            if (subtitle != null)
              Text(
                subtitle!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  color: filled
                      ? Colors.white.withValues(alpha: 0.85)
                      : MacaronColors.cocoa.withValues(alpha: 0.55),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 九大世界选关
class WorldMapPage extends StatefulWidget {
  const WorldMapPage({super.key});

  @override
  State<WorldMapPage> createState() => _WorldMapPageState();
}

class _WorldMapPageState extends State<WorldMapPage> {
  int world = 0;

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
                    child: const Icon(CupertinoIcons.back, color: MacaronColors.cocoa),
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
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                    onTap: locked
                        ? null
                        : () async {
                            await AudioService.instance.click();
                            if (!mounted) {
                              return;
                            }
                            await Navigator.push(
                              context,
                              CupertinoPageRoute<void>(
                                builder: (_) => PlayPage(
                                  worldIndex: world,
                                  levelIndex: level,
                                ),
                              ),
                            );
                            if (mounted) {
                              setState(() {});
                            }
                          },
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
                          border: Border.all(color: palette.accent.withValues(alpha: 0.35)),
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
                                  style: const TextStyle(fontSize: 10, color: MacaronColors.rose),
                                ),
                              if (best > 0)
                                Text(
                                  '纪录 $best',
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: MacaronColors.cocoa.withValues(alpha: 0.45),
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
      children: const [
        _TipCard(
          emoji: '🎯',
          title: '本关目标',
          body:
              '限时内跑到旗杆通关。第 11 关是 Boss 关，需先踩扁大 Boss 才能摸旗。',
        ),
        SizedBox(height: 10),
        _TipCard(
          emoji: '🕹️',
          title: '操作',
          body:
              '触控：← → 移动 · 蹲 · 跑 · 跳。\n键盘：方向键/WASD · 空格跳 · Shift 跑 · Esc 暂停。',
        ),
        SizedBox(height: 10),
        _TipCard(
          emoji: '🏳️',
          title: '检查点与敌人',
          body:
              '蓝色小旗：摸到后本局复活点前移。\n粉怪巡逻、橙怪会跳、红胖怪要踩两次。\nBoss 半血后变红狂暴并跳砸，踩多次才倒。',
        ),
        SizedBox(height: 10),
        _TipCard(
          emoji: '❓',
          title: '机关与商店',
          body:
              '顶「?」砖：糖 / 超级跳 / 积分糖特效。\n关卡糖果进钱包，首页「糖果商店」可换外观。',
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
          colors: [
            Colors.white,
            MacaronColors.blush.withValues(alpha: 0.25),
          ],
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
            colors: [
              Color(0xFFFFE8F0),
              MacaronColors.cream,
              Color(0xFFE8FFF6),
            ],
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
              ? [
                  Colors.white,
                  MacaronColors.lemon.withValues(alpha: 0.35),
                ]
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
                    backgroundColor: MacaronColors.blush.withValues(alpha: 0.28),
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

/// 关于页（上架信息）
class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return _SimplePage(
      title: '关于',
      children: const [
        Text('马卡龙女友跑酷', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
        Text('版本 1.4.0 · 全能打磨版'),
        SizedBox(height: 10),
        Text(
          '原创甜蜜平台跳跃单机。99 关、检查点、狂暴 Boss、耐打红胖怪、'
          '糖果商店、真拖尾外观、视差、分世界 BGM、键盘操作、本地存档，无联网无广告。'
          '已优化继续冒险、触控反馈、相机前瞻、长关性能与 iPhone 网页加载。',
        ),
        SizedBox(height: 10),
        Text('Android：Google Play / 各安卓商店 — 安装 apk 或自行签名上架。'),
        SizedBox(height: 10),
        Text('iPhone：App Store 需 Mac 或 Codemagic 云构建 ipa（见 docs/BUILD_IOS.md）；无 Mac 可用 Safari 网页版 + 添加到主屏幕。'),
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
            SwitchListTile(
              title: const Text('操作音效'),
              value: sound,
              activeThumbColor: MacaronColors.rose,
              onChanged: (v) async {
                setState(() => sound = v);
                await SaveService.instance.setSoundEnabled(v);
              },
            ),
            SwitchListTile(
              title: const Text('背景音乐'),
              value: music,
              activeThumbColor: MacaronColors.rose,
              onChanged: (v) async {
                setState(() => music = v);
                await SaveService.instance.setMusicEnabled(v);
                if (!v) {
                  // ignore: unawaited_futures
                  AudioService.instance.stopBgm();
                } else {
                  // ignore: unawaited_futures
                  AudioService.instance.resumeBgm();
                }
              },
            ),
            ListTile(
              title: const Text('音效音量'),
              subtitle: Slider(
                value: soundVol,
                activeColor: MacaronColors.rose,
                onChanged: (v) async {
                  setState(() => soundVol = v);
                  await SaveService.instance.setSoundVolume(v);
                  await AudioService.instance.applyVolumes();
                },
              ),
            ),
            ListTile(
              title: const Text('音乐音量'),
              subtitle: Slider(
                value: musicVol,
                activeColor: MacaronColors.lilac,
                onChanged: (v) async {
                  setState(() => musicVol = v);
                  await SaveService.instance.setMusicVolume(v);
                  await AudioService.instance.applyVolumes();
                },
              ),
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
                    await SaveService.instance
                        .setPlayerRole(PlayerRole.girlfriend);
                  },
                ),
                ChoiceChip(
                  label: const Text('男友'),
                  selected: role == PlayerRole.boyfriend,
                  selectedColor: MacaronColors.sky,
                  onSelected: (_) async {
                    setState(() => role = PlayerRole.boyfriend);
                    await SaveService.instance
                        .setPlayerRole(PlayerRole.boyfriend);
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
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('已重置教程，下次进关会再出现')),
                );
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
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('进度已清除')),
                    );
                  }
                }
              },
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
                      style: const TextStyle(color: MacaronColors.cocoa, height: 1.45, fontSize: 14),
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
