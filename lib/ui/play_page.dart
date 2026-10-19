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
    _showTutorial = !SaveService.instance.tutorialDone;
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
    final background =
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden;
    if (background) {
      // 一律停 BGM，避免教程/结算时切后台还响
      // ignore: unawaited_futures
      AudioService.instance.pauseBgm();
      if (_showTutorial || _busy || game.userPaused) {
        return;
      }
      _lifecyclePaused = true;
      setState(() {
        game.setPaused(true);
      });
    } else if (state == AppLifecycleState.resumed) {
      // ignore: unawaited_futures
      AudioService.instance.unlockAudio();
    }
  }

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
      final skill = switch (key) {
        LogicalKeyboardKey.keyJ => HeroSkill.dash,
        LogicalKeyboardKey.keyK => HeroSkill.shield,
        LogicalKeyboardKey.keyQ => HeroSkill.petalVolley,
        LogicalKeyboardKey.digit1 ||
        LogicalKeyboardKey.numpad1 => HeroSkill.pound,
        LogicalKeyboardKey.digit2 ||
        LogicalKeyboardKey.numpad2 => HeroSkill.airHop,
        LogicalKeyboardKey.digit3 ||
        LogicalKeyboardKey.numpad3 => HeroSkill.grapple,
        _ => null,
      };
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
        title: '🌍 世界通关！',
        body:
            '${WorldCatalog.paletteOf(widget.worldIndex).name} 已收官\n'
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
      title: '${List.filled(result.stars, '★').join()} 过关',
      body:
          '${LevelNames.of(widget.worldIndex, widget.levelIndex)}\n'
          '分数 ${result.score}\n'
          '糖果 ${result.coins}/${game.totalCoins} · 踩怪 ${result.kills}\n'
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
    final worldName = WorldCatalog.paletteOf(widget.worldIndex).name;
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
                      if (game.levelReady &&
                          _inputMode == InputMode.keyboard) ...[
                        const SizedBox(height: 6),
                        _SkillStrip(game: game, onCast: game.activateSkill),
                      ],
                      if (game.comboCount > 1) ...[
                        const SizedBox(height: 6),
                        Align(
                          alignment: Alignment.centerRight,
                          child: _HudChip(
                            child: Text(
                              '✨ 连击 ×${game.comboCount} · 下个 +${GameConstants.enemyComboBonusFor(game.comboCount + 1)}',
                              style: _hudText,
                            ),
                          ),
                        ),
                      ],
                      if (game.boss != null && !game.boss!.dead) ...[
                        const SizedBox(height: 8),
                        _BossHpBar(
                          hp: game.boss!.hp,
                          maxHp: game.boss!.maxHp,
                          enraged: game.boss!.enraged,
                          counterWindow: game.boss!.canReceiveProjectile,
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
                    onSkill: game.activateSkill,
                    onCycleSkill: game.cycleSelectedSkill,
                    onShoot: game.weaponVisible ? game.setShootPressed : null,
                    skillCooldown: game.skillCooldownRatio,
                    skillLabel: game.skillButtonLabel,
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
        if (game.weaponVisible) '🔫${game.gunTimer.ceil()}s',
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
          child: Text('🍬${game.collected}/${game.totalCoins}', style: style),
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

class _SkillStrip extends StatelessWidget {
  const _SkillStrip({required this.game, required this.onCast});

  final MacaronGame game;
  final void Function(HeroSkill skill) onCast;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      alignment: WrapAlignment.end,
      children: [
        for (final skill in HeroSkill.values)
          _SkillCastChip(
            keyLabel: skill.keyLabel,
            name: skill.shortLabel,
            cooldown: game.cooldownRatioOf(skill),
            onTap: () => onCast(skill),
          ),
      ],
    );
  }
}

class _SkillCastChip extends StatelessWidget {
  const _SkillCastChip({
    required this.keyLabel,
    required this.name,
    required this.cooldown,
    required this.onTap,
  });

  final String keyLabel;
  final String name;
  final double cooldown;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ready = cooldown <= 0;
    return Material(
      color: ready
          ? Colors.white.withValues(alpha: 0.88)
          : Colors.white.withValues(alpha: 0.45),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: ready ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Text(
            ready
                ? '$keyLabel $name'
                : '$keyLabel ${(cooldown * 100).round()}%',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: ready
                  ? MacaronColors.cocoa
                  : MacaronColors.cocoa.withValues(alpha: 0.45),
            ),
          ),
        ),
      ),
    );
  }
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

class _BossHpBar extends StatelessWidget {
  const _BossHpBar({
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            status,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: enraged ? MacaronColors.rose : MacaronColors.cocoa,
            ),
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 8,
              backgroundColor: Colors.black12,
              color: enraged ? MacaronColors.rose : MacaronColors.lilac,
            ),
          ),
          const SizedBox(height: 2),
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
