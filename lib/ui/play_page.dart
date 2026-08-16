import 'package:flame/game.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:macaron_girlfriend_run/data/audio_service.dart';
import 'package:macaron_girlfriend_run/data/game_models.dart';
import 'package:macaron_girlfriend_run/data/level_names.dart';
import 'package:macaron_girlfriend_run/data/save_service.dart';
import 'package:macaron_girlfriend_run/game/macaron_game.dart';
import 'package:macaron_girlfriend_run/theme/macaron_colors.dart';
import 'package:macaron_girlfriend_run/ui/controls.dart';
import 'package:macaron_girlfriend_run/ui/macaron_dialogs.dart';

/// 关卡游玩页
class PlayPage extends StatefulWidget {
  const PlayPage({
    super.key,
    required this.worldIndex,
    required this.levelIndex,
  });

  final int worldIndex;
  final int levelIndex;

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
    AudioService.instance.startBgm(worldIndex: widget.worldIndex);
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
    AudioService.instance.stopBgm();
    _focus.dispose();
    _hudTick.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final background = state == AppLifecycleState.paused ||
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

  void _onControlInteract() {
    // ignore: unawaited_futures
    AudioService.instance.unlockAudio();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    final down = event is KeyDownEvent;
    final up = event is KeyUpEvent;
    if (!down && !up) {
      return KeyEventResult.ignored;
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
    final pressed = down;
    if (key == LogicalKeyboardKey.arrowLeft || key == LogicalKeyboardKey.keyA) {
      game.leftPressed = pressed;
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight || key == LogicalKeyboardKey.keyD) {
      game.rightPressed = pressed;
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.shiftLeft ||
        key == LogicalKeyboardKey.shiftRight ||
        key == LogicalKeyboardKey.keyK) {
      game.runPressed = pressed;
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown || key == LogicalKeyboardKey.keyS) {
      game.setDuckPressed(pressed);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.space ||
        key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.keyJ ||
        key == LogicalKeyboardKey.keyW) {
      game.setJumpHeld(pressed);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Future<void> _showFreshAchievements() async {
    final fresh =
        await SaveService.instance.takeNewlyUnlockedAchievements();
    if (!mounted || fresh.isEmpty) {
      return;
    }
    for (final a in fresh) {
      if (!mounted) {
        return;
      }
      showAchievementToast(context, a.title, icon: a.icon);
      await Future<void>.delayed(const Duration(milliseconds: 700));
    }
  }

  Future<void> _handleWin(LevelResult result) async {
    if (_busy || !mounted) {
      return;
    }
    _busy = true;
    final global =
        SaveService.toGlobal(widget.worldIndex, widget.levelIndex);
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
        title: '💍 蜜月彩虹通关！',
        body: '你推开了全部 99 扇甜蜜大门\n'
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
        title: '🌍 世界通关！',
        body: '${WorldCatalog.paletteOf(widget.worldIndex).name} 已收官\n'
            '${List.filled(result.stars, '★').join()} · 分数 ${result.score}\n'
            '世界通关糖果已进钱包\n'
            '${game.starTips()}',
        actions: [
          MacaronDialogAction(
            label: '选关',
            onPressed: (ctx) {
              Navigator.pop(ctx);
              Navigator.pop(context, true);
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
      title: '${List.filled(result.stars, '★').join()} 过关',
      body: '${LevelNames.of(widget.worldIndex, widget.levelIndex)}\n'
          '分数 ${result.score}\n'
          '糖果 ${result.coins}/${game.totalCoins} · 踩怪 ${result.kills}\n'
          '剩余 ${result.timeLeft} 秒\n'
          '${game.starTips()}',
      actions: [
        MacaronDialogAction(
          label: '选关',
          onPressed: (ctx) {
            Navigator.pop(ctx);
            Navigator.pop(context, true);
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
            Navigator.pop(context);
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
  Widget build(BuildContext context) {
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
                      Row(
                        children: [
                          _HudChip(
                            onTap: (_showTutorial || _busy)
                                ? null
                                : _confirmExit,
                            child: const Icon(
                              CupertinoIcons.back,
                              size: 18,
                              color: MacaronColors.cocoa,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  worldName,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: MacaronColors.cocoa.withValues(
                                      alpha: 0.6,
                                    ),
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
                                    game.levelReady
                                        ? game.level.difficulty
                                        : 1,
                                  ),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: MacaronColors.rose.withValues(
                                      alpha: 0.75,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _HudChip(
                            child: Text('❤️×${game.lives}', style: _hudText),
                          ),
                          const SizedBox(width: 6),
                          _HudChip(
                            child: Text(
                              '🍬${game.collected}/${game.totalCoins}',
                              style: _hudText,
                            ),
                          ),
                          const SizedBox(width: 6),
                          _HudChip(
                            child: Text('${game.score}', style: _hudText),
                          ),
                          const SizedBox(width: 6),
                          _HudChip(
                            child: Text(
                              '${game.timeLeft.ceil()}s',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: game.timeLeft < 30
                                    ? MacaronColors.rose
                                    : MacaronColors.cocoa,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          _HudChip(
                            onTap: (_showTutorial || _busy)
                                ? null
                                : _togglePause,
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
                      if (game.boss != null && !game.boss!.dead) ...[
                        const SizedBox(height: 8),
                        _BossHpBar(
                          hp: game.boss!.hp,
                          maxHp: game.boss!.maxHp,
                          enraged: game.boss!.enraged,
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
                child: TouchControls(
                  scale: SaveService.instance.controlScale,
                  onInteract: _onControlInteract,
                  onLeft: (v) => game.leftPressed = v,
                  onRight: (v) => game.rightPressed = v,
                  onRun: (v) => game.runPressed = v,
                  onDuck: game.setDuckPressed,
                  onJumpHeld: game.setJumpHeld,
                ),
              ),
            if (game.userPaused && !_showTutorial)
              _PauseOverlay(
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
                      ),
                    ),
                  );
                },
              ),
            if (_showTutorial) _TutorialOverlay(onDone: _dismissTutorial),
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
  });

  final int hp;
  final int maxHp;
  final bool enraged;

  @override
  Widget build(BuildContext context) {
    final ratio = maxHp <= 0 ? 0.0 : (hp / maxHp).clamp(0.0, 1.0);
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
            enraged ? 'Boss 狂暴中' : 'Boss',
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
    this.fromLifecycle = false,
  });

  final VoidCallback onResume;
  final VoidCallback onQuit;
  final VoidCallback onRetry;
  final String starTips;
  final bool fromLifecycle;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black45,
      child: Center(
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
                    : '键盘：方向/WASD 移动 · 空格跳 · Shift 跑 · Esc 暂停',
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

class _TutorialOverlay extends StatelessWidget {
  const _TutorialOverlay({required this.onDone});

  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black54,
      child: Center(
        child: Container(
          width: 340,
          margin: const EdgeInsets.all(20),
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
              const Text('• 左移右移，右侧「蹲」「跑」「跳」（按下会缩小反馈）'),
              const Text('• 电脑可用方向键 / WASD + 空格跳'),
              const Text('• 跳要松手后再跳；短按短跳、长按跳得更高'),
              const Text('• 蓝色小旗 = 检查点（本局死后从旗子复活）'),
              const Text('• 头顶顶黄色「?」砖 → 糖 / 超级跳 / 积分糖'),
              const Text('• 红胖怪要踩 2 次；Boss 半血后会狂暴跳砸'),
              const Text('• 切到后台会自动暂停并停 BGM；限时死后不额外刷时间'),
              const Text('• 紫色马卡龙 = 超级跳跃；心 = 加命'),
              const Text('• 限时内通关摸旗；暂停菜单可看三星条件'),
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
        ),
      ),
    );
  }
}
