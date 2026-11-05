import 'package:flame/game.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:macaron_girlfriend_run/data/audio_service.dart';
import 'package:macaron_girlfriend_run/data/game_models.dart';
import 'package:macaron_girlfriend_run/data/level_names.dart';
import 'package:macaron_girlfriend_run/data/save_service.dart';
import 'package:macaron_girlfriend_run/game/macaron_game.dart';
import 'package:macaron_girlfriend_run/theme/macaron_colors.dart';
import 'package:macaron_girlfriend_run/ui/controls.dart';
import 'package:macaron_girlfriend_run/ui/game_viewport.dart';
import 'package:macaron_girlfriend_run/ui/home_page.dart';
import 'package:macaron_girlfriend_run/ui/input_mode.dart';
import 'package:macaron_girlfriend_run/ui/macaron_dialogs.dart';

/// 进关来源：决定「选关」回首页还是回选关地图。
enum PlayOrigin { home, map }

/// 「选关」动作：pop 回上一页，或用选关地图替换游戏页。
enum LevelSelectAction { pop, replaceWithMap }

class PlayNavigation {
  PlayNavigation._();

  /// map → pop；home → replaceWithMap。
  static LevelSelectAction levelSelectActionFor(PlayOrigin origin) =>
      switch (origin) {
        PlayOrigin.map => LevelSelectAction.pop,
        PlayOrigin.home => LevelSelectAction.replaceWithMap,
      };
}

/// 关卡游玩页
class PlayPage extends StatefulWidget {
  const PlayPage({
    super.key,
    required this.worldIndex,
    required this.levelIndex,
    this.origin = PlayOrigin.map,
  });

  final int worldIndex;
  final int levelIndex;
  final PlayOrigin origin;

  @override
  State<PlayPage> createState() => _PlayPageState();
}

class _PlayPageState extends State<PlayPage> with WidgetsBindingObserver {
  late final MacaronGame game;
  late final ValueNotifier<int> _hudTick;
  final FocusNode _focus = FocusNode();
  bool _busy = false;
  bool _showTutorial = false;
  bool _lifecyclePaused = false;
  InputMode _inputMode = InputModeRules.initialFor(defaultTargetPlatform);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _hudTick = ValueNotifier(0);
    // 进关直接开玩，不再弹教程；想看玩法可以从主菜单的“玩法”进入。
    _showTutorial = false;
    SaveService.instance.setLastPlayed(widget.worldIndex, widget.levelIndex);
    game = MacaronGame(
      worldIndex: widget.worldIndex,
      levelIndex: widget.levelIndex,
      role: SaveService.instance.playerRole,
      onHudChanged: () {
        if (mounted) {
          _hudTick.value++;
        }
      },
      onWin: _handleWin,
      onLoseLife: () {
        if (mounted) {
          _hudTick.value++;
        }
      },
      onGameOver: _handleGameOver,
    );
    if (_showTutorial) {
      game.setPaused(true);
    }
    // ignore: unawaited_futures
    AudioService.instance.startBgm(
      worldIndex: widget.worldIndex,
      levelIndex: widget.levelIndex,
      boss: widget.levelIndex == GameConstants.levelsPerWorld - 1,
      owner: this,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focus.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // ignore: unawaited_futures
    AudioService.instance.stopBgm(owner: this);
    _focus.dispose();
    _hudTick.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // inactive 只是瞬时失焦（下拉通知栏、系统弹层、沉浸模式的边缘手势、
    // 网页失焦），不能当成切后台：否则点技能、跳跃时音乐和移动会被一起暂停。
    // 真正切到后台一定会继续进入 hidden / paused。
    final background =
        state == AppLifecycleState.paused || state == AppLifecycleState.hidden;
    if (background) {
      // 一律停 BGM，避免教程/结算时切后台还响
      // ignore: unawaited_futures
      AudioService.instance.pauseBgm();
      if (_showTutorial || _busy || game.userPaused) {
        return;
      }
      _lifecyclePaused = true;
      _backgroundSince = Stopwatch()..start();
      setState(() {
        game.setPaused(true);
      });
    } else if (state == AppLifecycleState.resumed) {
      // ignore: unawaited_futures
      AudioService.instance.unlockAudio(force: true);
      final away = _backgroundSince?.elapsedMilliseconds;
      _backgroundSince = null;
      if (_lifecyclePaused) {
        // 只是瞬间离开（浏览器抖动、系统弹层一闪而过）：回来自动继续，
        // 不让玩家卡在暂停画面里；离开较久则保留暂停画面等玩家准备好。
        if (away != null && away < _quickReturnMs && mounted && !_busy) {
          _lifecyclePaused = false;
          setState(() {
            game.setPaused(false);
          });
          // ignore: unawaited_futures
          AudioService.instance.resumeBgm();
        }
      } else if (!game.userPaused) {
        // 不是由切后台造成的暂停（教程、结算期间）：回来时只需恢复音乐。
        // ignore: unawaited_futures
        AudioService.instance.resumeBgm();
      }
    }
  }

  /// 离开不超过这个时长就算“瞬间离开”，回来自动继续。
  static const int _quickReturnMs = 2000;
  Stopwatch? _backgroundSince;

  void _setInputMode(InputMode mode) {
    if (_inputMode != mode) {
      setState(() => _inputMode = mode);
    }
  }

  void _onControlInteract() {
    // ignore: unawaited_futures
    AudioService.instance.unlockAudio();
    _setInputMode(InputMode.touch);
  }

  /// 「选关」：来自地图则返回，来自首页则用选关地图替换本页（停在当前世界）。
  void _goToLevelSelect() {
    switch (PlayNavigation.levelSelectActionFor(widget.origin)) {
      case LevelSelectAction.pop:
        Navigator.pop(context, true);
      case LevelSelectAction.replaceWithMap:
        Navigator.pushReplacement(
          context,
          CupertinoPageRoute<void>(
            builder: (_) => WorldMapPage(initialWorld: widget.worldIndex),
          ),
        );
    }
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    final down = event is KeyDownEvent;
    final up = event is KeyUpEvent;
    if (!down && !up) {
      return KeyEventResult.ignored;
    }
    if (down) {
      AudioService.instance.unlockAudio();
      _setInputMode(InputMode.keyboard);
    }
    final key = event.logicalKey;
    if (down &&
        (key == LogicalKeyboardKey.escape || key == LogicalKeyboardKey.keyP)) {
      if (!_showTutorial && !_busy) {
        _togglePause();
      }
      return KeyEventResult.handled;
    }
    // 暂停/教程/结算时不接收移动键，避免粘键
    if (_showTutorial || _busy || game.userPaused) {
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyF) {
      game.setShootPressed(down);
      return KeyEventResult.handled;
    }
    if (down) {
      final skill = key == LogicalKeyboardKey.keyJ ? HeroSkill.dash : null;
      if (skill != null) {
        game.activateSkill(skill);
        return KeyEventResult.handled;
      }
    }
    final pressed = down;
    if (key == LogicalKeyboardKey.arrowLeft || key == LogicalKeyboardKey.keyA) {
      game.leftPressed = pressed;
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.keyD) {
      game.rightPressed = pressed;
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.shiftLeft ||
        key == LogicalKeyboardKey.shiftRight) {
      game.runPressed = pressed;
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown || key == LogicalKeyboardKey.keyS) {
      game.setDuckPressed(pressed);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.space ||
        key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.keyW) {
      game.setJumpHeld(pressed);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Future<void> _showFreshAchievements() async {
    final fresh = await SaveService.instance.takeNewlyUnlockedAchievements();
    if (!mounted || fresh.isEmpty) {
      return;
    }
    for (final a in fresh) {
      if (!mounted) {
        return;
      }
      showAchievementToast(context, a.title, icon: a.icon, landscape: true);
      await Future<void>.delayed(const Duration(milliseconds: 700));
    }
  }

  Future<void> _handleWin(LevelResult result) async {
    if (_busy || !mounted) {
      return;
    }
    _busy = true;
    if (widget.levelIndex == GameConstants.depthLevelIndex) {
      // 歌曲深处不占 99 关进度：只记糖果和成绩统计。
      await SaveService.instance.addRunStats(
        coins: result.coins,
        score: result.score,
        kills: result.kills,
        cleared: false,
        bossCleared: false,
      );
      if (!mounted) {
        return;
      }
      await showMacaronDialog<void>(
        context: context,
        landscape: true,
        celebration: true,
        title: '${List.filled(result.stars, '★').join()} 到底了',
        body:
            '${WorldCatalog.paletteOf(widget.worldIndex).displayName} · 歌曲深处\n'
            '分数 ${result.score} · ${game.songTheme.collectibleName} ${result.coins}/${game.totalCoins}',
        actions: [
          MacaronDialogAction(
            label: '选关',
            primary: true,
            onPressed: (ctx) {
              Navigator.pop(ctx);
              _goToLevelSelect();
            },
          ),
        ],
      );
      return;
    }
    final global = SaveService.toGlobal(widget.worldIndex, widget.levelIndex);
    await SaveService.instance.setStars(global, result.stars);
    await SaveService.instance.setBestScore(global, result.score);
    await SaveService.instance.unlockThrough(global + 1);
    if (widget.levelIndex == GameConstants.levelsPerWorld - 1) {
      await SaveService.instance.grantWorldClearBonus(widget.worldIndex);
    }
    await SaveService.instance.addRunStats(
      coins: result.coins,
      score: result.score,
      kills: result.kills,
      cleared: true,
      bossCleared: result.bossCleared,
    );
    await _showFreshAchievements();
    if (!mounted) {
      return;
    }

    final isLast =
        widget.worldIndex == GameConstants.worldCount - 1 &&
        widget.levelIndex == GameConstants.levelsPerWorld - 1;

    if (isLast && !SaveService.instance.allClearCelebrated) {
      await SaveService.instance.setAllClearCelebrated();
      if (!mounted) {
        return;
      }
      await showMacaronDialog<void>(
        context: context,
        landscape: true,
        celebration: true,
        title: '💍 蜜月彩虹通关！',
        body:
            '你推开了全部 99 扇甜蜜大门\n'
            '分数 ${result.score} · ${List.filled(result.stars, '★').join()}\n'
            '去商店换一套纪念外观吧\n'
            '全通成就已点亮，随时可以三星重刷～',
        actions: [
          MacaronDialogAction(
            label: '回首页庆祝',
            primary: true,
            onPressed: (ctx) {
              Navigator.pop(ctx);
              Navigator.pop(context, true);
            },
          ),
        ],
      );
      return;
    }

    if (widget.levelIndex == GameConstants.levelsPerWorld - 1) {
      await showMacaronDialog<void>(
        context: context,
        landscape: true,
        celebration: true,
        title: '🌍 世界通关！',
        body:
            '${WorldCatalog.paletteOf(widget.worldIndex).displayName} 已收官\n'
            '${List.filled(result.stars, '★').join()} · 分数 ${result.score}\n'
            '世界通关糖果已进钱包\n'
            '${game.starTips()}',
        actions: [
          MacaronDialogAction(
            label: '选关',
            onPressed: (ctx) {
              Navigator.pop(ctx);
              _goToLevelSelect();
            },
          ),
          if (widget.worldIndex < GameConstants.worldCount - 1)
            MacaronDialogAction(
              label: '下一世界',
              primary: true,
              onPressed: (ctx) {
                Navigator.pop(ctx);
                final next = SaveService.fromGlobal(global + 1);
                Navigator.pushReplacement(
                  context,
                  CupertinoPageRoute<void>(
                    builder: (_) => PlayPage(
                      worldIndex: next.$1,
                      levelIndex: next.$2,
                      origin: widget.origin,
                    ),
                  ),
                );
              },
            ),
        ],
      );
      return;
    }

    await showMacaronDialog<void>(
      context: context,
      landscape: true,
      celebration: true,
      title: '${List.filled(result.stars, '★').join()} 过关',
      body:
          '${LevelNames.of(widget.worldIndex, widget.levelIndex)}\n'
          '分数 ${result.score}\n'
          '${game.songTheme.collectibleName} ${result.coins}/${game.totalCoins} · 踩怪 ${result.kills}\n'
          '剩余 ${result.timeLeft} 秒\n'
          '${game.starTips()}',
      actions: [
        MacaronDialogAction(
          label: '选关',
          onPressed: (ctx) {
            Navigator.pop(ctx);
            _goToLevelSelect();
          },
        ),
        if (widget.levelIndex < GameConstants.levelsPerWorld - 1 ||
            widget.worldIndex < GameConstants.worldCount - 1)
          MacaronDialogAction(
            label: '下一关',
            primary: true,
            onPressed: (ctx) {
              Navigator.pop(ctx);
              final next = SaveService.fromGlobal(global + 1);
              Navigator.pushReplacement(
                context,
                CupertinoPageRoute<void>(
                  builder: (_) => PlayPage(
                    worldIndex: next.$1,
                    levelIndex: next.$2,
                    origin: widget.origin,
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  Future<void> _handleGameOver() async {
    if (_busy || !mounted) {
      return;
    }
    _busy = true;
    await SaveService.instance.addRunStats(
      coins: game.collected,
      score: game.score,
      kills: game.kills,
      cleared: false,
    );
    await _showFreshAchievements();
    if (!mounted) {
      return;
    }
    await showMacaronDialog<void>(
      context: context,
      landscape: true,
      title: '再试一次嘛',
      body: '本关分数 ${game.score}\n检查点会记住你跑过的旗子哦',
      actions: [
        MacaronDialogAction(
          label: '返回',
          onPressed: (ctx) {
            Navigator.pop(ctx);
            Navigator.pop(context);
          },
        ),
        MacaronDialogAction(
          label: '再来一局',
          primary: true,
          onPressed: (ctx) {
            Navigator.pop(ctx);
            Navigator.pushReplacement(
              context,
              CupertinoPageRoute<void>(
                builder: (_) => PlayPage(
                  worldIndex: widget.worldIndex,
                  levelIndex: widget.levelIndex,
                  origin: widget.origin,
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  void _togglePause() {
    if (_showTutorial || _busy) {
      return;
    }
    AudioService.instance.click();
    final pausing = !game.userPaused;
    setState(() {
      game.setPaused(pausing);
      if (!pausing) {
        _lifecyclePaused = false;
      }
    });
    if (pausing) {
      // ignore: unawaited_futures
      AudioService.instance.pauseBgm();
    } else {
      // ignore: unawaited_futures
      AudioService.instance.resumeBgm();
    }
  }

  Future<void> _confirmExit() async {
    game.setPaused(true);
    // ignore: unawaited_futures
    AudioService.instance.pauseBgm();
    await showMacaronDialog<void>(
      context: context,
      landscape: true,
      title: '先休息一下？',
      body: '退出后本关进度不会保存\n（检查点只在本局有效）',
      actions: [
        MacaronDialogAction(
          label: '继续玩',
          primary: true,
          onPressed: (ctx) {
            Navigator.pop(ctx);
            setState(() {
              game.setPaused(false);
            });
            // ignore: unawaited_futures
            AudioService.instance.resumeBgm();
          },
        ),
        MacaronDialogAction(
          label: '确认退出',
          onPressed: (ctx) {
            Navigator.pop(ctx);
            _goToLevelSelect();
          },
        ),
      ],
    );
  }

  Future<void> _dismissTutorial() async {
    await SaveService.instance.setTutorialDone();
    await AudioService.instance.unlockAudio();
    if (!mounted) {
      return;
    }
    setState(() {
      _showTutorial = false;
      game.setPaused(false);
    });
    // ignore: unawaited_futures
    AudioService.instance.resumeBgm();
  }

  @override
  Widget build(BuildContext context) => GameViewport(
    onGeometryChanged: game.clearInput,
    child: Builder(builder: _buildPlayView),
  );

  Widget _buildPlayView(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    final levelTitle = LevelNames.of(widget.worldIndex, widget.levelIndex);
    final worldName =
        '${WorldCatalog.paletteOf(widget.worldIndex).displayName}'
        ' ♪ ${AudioService.songTitleFor(widget.worldIndex)}';
    final sky = WorldCatalog.paletteOf(widget.worldIndex).skyBottom;

    return Focus(
      focusNode: _focus,
      autofocus: true,
      onKeyEvent: _onKey,
      child: Scaffold(
        backgroundColor: sky,
        body: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: sky),
            RepaintBoundary(
              child: GameWidget(
                game: game,
                loadingBuilder: (_) => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CupertinoActivityIndicator(),
                      const SizedBox(height: 12),
                      Text(
                        '加载关卡…',
                        style: TextStyle(
                          color: MacaronColors.cocoa.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                errorBuilder: (_, error) => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      '关卡加载失败\n请返回重试',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: MacaronColors.cocoa,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: pad.top + 8,
              left: 12 + pad.left,
              right: 12 + pad.right,
              child: ValueListenableBuilder<int>(
                valueListenable: _hudTick,
                builder: (_, __, ___) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _GameHudHeader(
                        game: game,
                        worldName: worldName,
                        levelTitle: levelTitle,
                        onPause: (_showTutorial || _busy) ? null : _togglePause,
                      ),
                      if (game.comboCount > 1) ...[
                        const SizedBox(height: 6),
                        Align(
                          alignment: Alignment.centerRight,
                          child: _HudChip(
                            child: Text(
                              '✨ ×${game.comboCount}',
                              style: _hudText,
                            ),
                          ),
                        ),
                      ],
                      if (game.boss != null && !game.boss!.dead) ...[
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.topCenter,
                          child: BossHpBar(
                            hp: game.boss!.hp,
                            maxHp: game.boss!.maxHp,
                            enraged: game.boss!.enraged,
                            counterWindow: game.boss!.canReceiveProjectile,
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
            ValueListenableBuilder<int>(
              valueListenable: _hudTick,
              builder: (_, __, ___) {
                if (!game.poweredUpVisible) {
                  return const SizedBox.shrink();
                }
                return Positioned(
                  top: pad.top + 88,
                  left: 0,
                  right: 0,
                  child: const Center(
                    child: Text(
                      '超级跳跃中',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: MacaronColors.lilac,
                        shadows: [Shadow(color: Colors.white, blurRadius: 6)],
                      ),
                    ),
                  ),
                );
              },
            ),
            if (!game.userPaused && !_showTutorial)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: ValueListenableBuilder<int>(
                  valueListenable: _hudTick,
                  builder: (_, __, ___) => TouchControls(
                    scale: SaveService.instance.controlScale,
                    onInteract: _onControlInteract,
                    onLeft: (v) => game.leftPressed = v,
                    onRight: (v) => game.rightPressed = v,
                    onRun: (v) => game.runPressed = v,
                    onDuck: game.setDuckPressed,
                    onJumpHeld: game.setJumpHeld,
                    onVertical: (v) {
                      game.upPressed = v < 0;
                      game.downPressed = v > 0;
                    },
                    onSkill: () => game.activateSkill(HeroSkill.dash),
                    onShoot: game.weaponVisible ? game.setShootPressed : null,
                    skillCooldown: game.cooldownRatioOf(HeroSkill.dash),
                    skillLabel: '撞击',
                  ),
                ),
              ),
            if (game.userPaused && !_showTutorial)
              _PauseOverlay(
                inputMode: _inputMode,
                fromLifecycle: _lifecyclePaused,
                starTips: game.starTips(),
                onResume: _togglePause,
                onQuit: _confirmExit,
                onRetry: () {
                  Navigator.pushReplacement(
                    context,
                    CupertinoPageRoute<void>(
                      builder: (_) => PlayPage(
                        worldIndex: widget.worldIndex,
                        levelIndex: widget.levelIndex,
                        origin: widget.origin,
                      ),
                    ),
                  );
                },
              ),
            if (_showTutorial)
              TutorialOverlay(onDone: _dismissTutorial, inputMode: _inputMode),
          ],
        ),
      ),
    );
  }

  static const _hudText = TextStyle(
    fontWeight: FontWeight.w700,
    fontSize: 13,
    color: MacaronColors.cocoa,
  );
}

class _GameHudHeader extends StatelessWidget {
  const _GameHudHeader({
    required this.game,
    required this.worldName,
    required this.levelTitle,
    this.onPause,
  });
  final MacaronGame game;
  final String worldName;
  final String levelTitle;
  final VoidCallback? onPause;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final compact = constraints.maxWidth < 760;
      const style = TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: MacaronColors.cocoa,
      );
      final equipment = [
        if (game.weaponVisible) '🔫零元购${game.gunTimer.ceil()}s',
        if (game.superTimer > 0) '🦸${game.superTimer.ceil()}s',
        if (game.planeTimer > 0) '✈️${game.planeTimer.ceil()}s',
        if (game.gumTimer > 0) '🫧${game.gumTimer.ceil()}s',
        if (game.plantBuddyTimer > 0) '🌱${game.plantBuddyTimer.ceil()}s',
        if (game.vehicleTimer > 0) '🚙${game.vehicleTimer.ceil()}s',
        if (game.vehicleBoosting) '加速',
        if (game.vehicleChargeRatio > 0)
          '蓄力${(game.vehicleChargeRatio * 100).round()}%',
      ];
      final stats = <Widget>[
        if (equipment.isNotEmpty)
          _HudChip(child: Text(equipment.join(' '), style: style)),
        _HudChip(child: Text('❤️×${game.lives}', style: style)),
        _HudChip(
          child: Text(
            '${game.songTheme.collectibleName} ${game.collected}/${game.totalCoins}',
            style: style,
          ),
        ),
        Tooltip(
          message: game.songTheme.rewardDescription,
          child: _HudChip(
            child: Text(
              '${game.songTheme.rewardName} ${game.songRewardProgress}/${MacaronGame.songRewardThreshold}',
              style: style,
            ),
          ),
        ),
        _HudChip(child: Text('${game.score}', style: style)),
        _HudChip(
          child: Text(
            '${game.timeLeft.ceil()}s',
            style: style.copyWith(
              color: game.timeLeft < 30
                  ? MacaronColors.rose
                  : MacaronColors.cocoa,
            ),
          ),
        ),
      ];
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      worldName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: MacaronColors.cocoa.withValues(alpha: 0.6),
                      ),
                    ),
                    Text(
                      levelTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: MacaronColors.cocoa,
                      ),
                    ),
                    Text(
                      GameConstants.difficultyLabel(
                        game.levelReady ? game.level.difficulty : 1,
                      ),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: MacaronColors.rose.withValues(alpha: 0.75),
                      ),
                    ),
                  ],
                ),
              ),
              if (!compact)
                ...stats.map(
                  (stat) => Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: stat,
                  ),
                ),
              _HudChip(
                onTap: onPause,
                child: Icon(
                  game.userPaused
                      ? CupertinoIcons.play_fill
                      : CupertinoIcons.pause_fill,
                  size: 16,
                  color: MacaronColors.cocoa,
                ),
              ),
            ],
          ),
          if (compact) ...[
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: Wrap(spacing: 6, runSpacing: 4, children: stats),
            ),
          ],
        ],
      );
    },
  );
}

class _HudChip extends StatelessWidget {
  const _HudChip({required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final box = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
    if (onTap == null) {
      return box;
    }
    return GestureDetector(onTap: onTap, child: box);
  }
}

class BossHpBar extends StatelessWidget {
  const BossHpBar({
    super.key,
    required this.hp,
    required this.maxHp,
    required this.enraged,
    required this.counterWindow,
  });

  final int hp;
  final int maxHp;
  final bool enraged;
  final bool counterWindow;

  @override
  Widget build(BuildContext context) {
    final ratio = maxHp <= 0 ? 0.0 : (hp / maxHp).clamp(0.0, 1.0);
    final status = counterWindow
        ? 'Boss 狂暴 · 糖弹可反击'
        : enraged
        ? 'Boss 狂暴中'
        : 'Boss · 踩踏破防';
    return Container(
      constraints: const BoxConstraints(maxWidth: 260, maxHeight: 40),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Text(
            status,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: enraged ? MacaronColors.rose : MacaronColors.cocoa,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 8,
                backgroundColor: Colors.black12,
                color: enraged ? MacaronColors.rose : MacaronColors.lilac,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$hp / $maxHp',
            style: TextStyle(
              fontSize: 10,
              color: MacaronColors.cocoa.withValues(alpha: 0.55),
            ),
          ),
        ],
      ),
    );
  }
}

class _PauseOverlay extends StatelessWidget {
  const _PauseOverlay({
    required this.onResume,
    required this.onQuit,
    required this.onRetry,
    required this.starTips,
    required this.inputMode,
    this.fromLifecycle = false,
  });

  final VoidCallback onResume;
  final VoidCallback onQuit;
  final VoidCallback onRetry;
  final String starTips;
  final InputMode inputMode;
  final bool fromLifecycle;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black45,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: Container(
            width: 300,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: MacaronColors.cream,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  fromLifecycle ? '切到后台啦' : '暂停',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: MacaronColors.cocoa,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  fromLifecycle
                      ? '回来点「继续」就能接着跑～限时已帮你停住'
                      : '${InputModeRules.linesFor(inputMode).join(' · ')}\n蓝台可从下穿过 · 黄台会塌 · 紫台会带着走',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    color: MacaronColors.cocoa.withValues(alpha: 0.55),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  starTips,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: MacaronColors.rose,
                  ),
                ),
                const SizedBox(height: 16),
                _menuBtn('继续', onResume, filled: true),
                const SizedBox(height: 10),
                _menuBtn('重试本关', onRetry),
                const SizedBox(height: 10),
                _menuBtn('退出选关', onQuit),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _menuBtn(String label, VoidCallback onTap, {bool filled = false}) {
    return SizedBox(
      width: double.infinity,
      child: CupertinoButton(
        color: filled ? MacaronColors.rose : Colors.white,
        borderRadius: BorderRadius.circular(16),
        onPressed: onTap,
        child: Text(
          label,
          style: TextStyle(
            color: filled ? Colors.white : MacaronColors.cocoa,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

/// 首次进关的操作说明；公开是为了让矮屏布局可以单独测试。
class TutorialOverlay extends StatelessWidget {
  const TutorialOverlay({
    super.key,
    required this.onDone,
    this.inputMode = InputMode.touch,
  });

  final VoidCallback onDone;
  final InputMode inputMode;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black54,
      child: Center(
        // 矮屏（横屏手机约 375 高）上标题和“开始冒险”固定可见，只滚动中间的说明。
        child: LayoutBuilder(
          builder: (context, constraints) {
            final margin = constraints.maxHeight < 480 ? 8.0 : 20.0;
            return Container(
              width: 340,
              constraints: BoxConstraints(
                maxHeight: constraints.maxHeight - margin * 2,
              ),
              margin: EdgeInsets.symmetric(horizontal: 20, vertical: margin),
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: MacaronColors.cream,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '怎么玩',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: MacaronColors.cocoa,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final line in InputModeRules.linesFor(inputMode))
                            Text('• $line'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: CupertinoButton(
                      color: MacaronColors.rose,
                      borderRadius: BorderRadius.circular(16),
                      onPressed: onDone,
                      child: const Text(
                        '开始冒险',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
