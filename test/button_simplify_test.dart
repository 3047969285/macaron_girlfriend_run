// 按钮精简（v1.6）验收测试，对应 docs/按钮精简/PRD.md 的 R1–R10。
import 'package:flame/game.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:macaron_girlfriend_run/data/game_models.dart';
import 'package:macaron_girlfriend_run/data/save_service.dart';
import 'package:macaron_girlfriend_run/game/macaron_game.dart';
import 'package:macaron_girlfriend_run/ui/controls.dart';
import 'package:macaron_girlfriend_run/ui/home_page.dart';
import 'package:macaron_girlfriend_run/ui/input_mode.dart';
import 'package:macaron_girlfriend_run/ui/play_page.dart';
import 'package:macaron_girlfriend_run/ui/shop_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _initSave([Map<String, Object> values = const {}]) async {
  SharedPreferences.setMockInitialValues({
    'sound_on': false,
    'music_on': false,
    'haptic_on': false,
    ...values,
  });
  await SaveService.instance.init();
}

Future<void> _useTallView(WidgetTester tester) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(900, 2400);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  group('R1 首页精简', () {
    testWidgets('首页只剩 6 个入口，没有 iPhone 版和关于链接', (tester) async {
      await _initSave();
      await _useTallView(tester);
      await tester.pumpWidget(const MaterialApp(home: HomePage()));
      await tester.pump();

      expect(find.text('iPhone 版'), findsNothing);
      expect(find.text('关于与上架说明'), findsNothing);
      for (final label in ['继续冒险', '选关地图', '糖果商店', '玩法', '任务', '设置']) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
    });
  });

  group('R2 关于页', () {
    testWidgets('不含开发者上架信息，保留隐私说明', (tester) async {
      await _useTallView(tester);
      await tester.pumpWidget(const MaterialApp(home: AboutPage()));
      expect(find.textContaining('BUILD_IOS'), findsNothing);
      expect(find.textContaining('Codemagic'), findsNothing);
      expect(find.textContaining('apk'), findsNothing);
      expect(find.textContaining('隐私'), findsOneWidget);
    });
  });

  group('R3 技能入口合并', () {
    testWidgets('选中技能从当关技能开始，可循环切换，无参释放选中技能', (tester) async {
      await _initSave();
      final game = MacaronGame(
        worldIndex: 0,
        levelIndex: 2,
        role: PlayerRole.girlfriend,
      );
      await tester.pumpWidget(GameWidget(game: game));
      await tester.pump(const Duration(milliseconds: 100));
      expect(game.levelReady, isTrue);
      game.pauseEngine();

      final start = GameConstants.heroSkillForLevel(0, 2);
      expect(game.selectedSkill, start);
      expect(game.activeSkill, start);

      game.cycleSelectedSkill();
      final next =
          HeroSkill.values[(start.index + 1) % HeroSkill.values.length];
      expect(game.selectedSkill, next);
      expect(game.activeSkill, start, reason: '当关技能不随切换改变');
      expect(game.skillButtonLabel, next.shortLabel);

      game.activateSkill();
      expect(game.cooldownRatioOf(next), greaterThan(0));
      expect(game.cooldownRatioOf(start), 0);
      expect(game.skillCooldownRatio, game.cooldownRatioOf(next));

      // 有参释放不改变选中技能
      final other = HeroSkill.values.firstWhere((s) => s != next);
      game.activateSkill(other);
      expect(game.selectedSkill, next);

      for (var i = 0; i < HeroSkill.values.length - 1; i++) {
        game.cycleSelectedSkill();
      }
      expect(game.selectedSkill, start, reason: '切 6 次回到原技能');
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('触屏「换」按钮可点，窄屏不溢出', (tester) async {
      tester.view.devicePixelRatio = 1;
      for (final size in const [Size(320, 720), Size(844, 390)]) {
        tester.view.physicalSize = size;
        var cycled = 0;
        var interacted = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Stack(
                children: [
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: TouchControls(
                      onLeft: (_) {},
                      onRight: (_) {},
                      onRun: (_) {},
                      onDuck: (_) {},
                      onJumpHeld: (_) {},
                      onSkill: () {},
                      onShoot: (_) {},
                      onCycleSkill: () => cycled++,
                      onInteract: () => interacted++,
                      skillLabel: '闪冲',
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull, reason: '$size');
        expect(find.text('换'), findsOneWidget, reason: '$size');
        await tester.tap(find.text('换'));
        await tester.pump();
        expect(cycled, 1, reason: '$size');
        expect(interacted, greaterThan(0), reason: '$size');
      }
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    testWidgets('不传 onCycleSkill 时没有「换」按钮', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: TouchControls(
                    onLeft: (_) {},
                    onRight: (_) {},
                    onRun: (_) {},
                    onJumpHeld: (_) {},
                    onSkill: () {},
                    skillLabel: '闪冲',
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      expect(find.text('换'), findsNothing);
    });

    test('输入模式按平台定初值', () {
      for (final p in [
        TargetPlatform.macOS,
        TargetPlatform.windows,
        TargetPlatform.linux,
      ]) {
        expect(InputModeRules.initialFor(p), InputMode.keyboard, reason: '$p');
      }
      for (final p in [
        TargetPlatform.iOS,
        TargetPlatform.android,
        TargetPlatform.fuchsia,
      ]) {
        expect(InputModeRules.initialFor(p), InputMode.touch, reason: '$p');
      }
    });
  });

  group('R5 选关去地图', () {
    test('来源决定选关动作', () {
      expect(
        PlayNavigation.levelSelectActionFor(PlayOrigin.map),
        LevelSelectAction.pop,
      );
      expect(
        PlayNavigation.levelSelectActionFor(PlayOrigin.home),
        LevelSelectAction.replaceWithMap,
      );
    });

    test('PlayPage 默认来自地图', () {
      const page = PlayPage(worldIndex: 0, levelIndex: 0);
      expect(page.origin, PlayOrigin.map);
    });

    testWidgets('地图可指定初始世界，越界夹紧', (tester) async {
      await _initSave();
      await _useTallView(tester);
      final third = WorldCatalog.paletteOf(3).name;
      await tester.pumpWidget(
        const MaterialApp(home: WorldMapPage(initialWorld: 3)),
      );
      await tester.pump();
      expect(find.textContaining('$third · 选关'), findsOneWidget);

      final last = WorldCatalog.paletteOf(GameConstants.worldCount - 1).name;
      await tester.pumpWidget(
        const MaterialApp(home: WorldMapPage(initialWorld: 99)),
      );
      await tester.pump();
      expect(find.textContaining('$last · 选关'), findsOneWidget);
    });
  });

  group('R6 音量开关并入滑块', () {
    test('显示值：开关关时为 0', () {
      expect(AudioSliderRules.display(enabled: false, volume: 0.8), 0);
      expect(AudioSliderRules.display(enabled: true, volume: 0.8), 0.8);
    });

    test('拖动：音量即新值，大于 0 才算开', () {
      final off = AudioSliderRules.apply(0);
      expect(off.enabled, isFalse);
      expect(off.volume, 0);
      final on = AudioSliderRules.apply(0.5);
      expect(on.enabled, isTrue);
      expect(on.volume, 0.5);
    });

    testWidgets('设置页没有音效/音乐开关，老存档关掉的显示 0', (tester) async {
      await _initSave({
        'sound_on': false,
        'sound_volume': 0.8,
        'music_on': true,
        'music_volume': 0.6,
      });
      await _useTallView(tester);
      await tester.pumpWidget(const MaterialApp(home: SettingsPage()));
      await tester.pump();

      expect(find.text('操作音效'), findsNothing);
      expect(find.text('背景音乐'), findsNothing);
      expect(find.text('音效音量'), findsOneWidget);
      expect(find.text('音乐音量'), findsOneWidget);

      final sliders = tester.widgetList<Slider>(find.byType(Slider)).toList();
      // 顺序：音效音量、音乐音量、按钮大小
      expect(sliders[0].value, 0);
      expect(sliders[1].value, closeTo(0.6, 1e-9));
    });
  });

  group('R7 帧率只在 Android 显示', () {
    testWidgets('iOS 隐藏、Android 显示', (tester) async {
      await _initSave();
      await _useTallView(tester);

      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      expect(FpsBootstrap.isSupported, isFalse);
      await tester.pumpWidget(const MaterialApp(home: SettingsPage()));
      await tester.pump();
      expect(find.text('帧率'), findsNothing);
      expect(find.text('120'), findsNothing);

      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      expect(FpsBootstrap.isSupported, isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(const MaterialApp(home: SettingsPage()));
      await tester.pump();
      expect(find.text('帧率'), findsOneWidget);
      expect(find.text('120'), findsOneWidget);

      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('设置页底部有「关于」，点进关于页', (tester) async {
      await _initSave();
      await _useTallView(tester);
      await tester.pumpWidget(const MaterialApp(home: SettingsPage()));
      await tester.pump();
      await tester.scrollUntilVisible(find.text('关于'), 200);
      await tester.tap(find.text('关于'));
      await tester.pumpAndSettle();
      expect(find.byType(AboutPage), findsOneWidget);
    });
  });

  group('R8 商店', () {
    testWidgets('「穿戴中」按钮禁用', (tester) async {
      await _initSave();
      await _useTallView(tester);
      await tester.pumpWidget(const MaterialApp(home: ShopPage()));
      await tester.pump();
      final button = tester.widget<CupertinoButton>(
        find.ancestor(
          of: find.text('穿戴中'),
          matching: find.byType(CupertinoButton),
        ),
      );
      expect(button.onPressed, isNull);
    });
  });

  group('R9 说明文字', () {
    test('触屏说明提到「换」，键盘说明含 F 和 Esc', () {
      expect(InputModeRules.touchLines.any((l) => l.contains('换')), isTrue);
      final keys = InputModeRules.keyboardLines.join(' ');
      expect(keys, contains('F'));
      expect(keys, contains('Esc'));
      expect(
        InputModeRules.linesFor(InputMode.touch),
        InputModeRules.touchLines,
      );
      expect(
        InputModeRules.linesFor(InputMode.keyboard),
        InputModeRules.keyboardLines,
      );
    });

    testWidgets('教程按输入模式显示', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: TutorialOverlay(onDone: () {})),
      );
      expect(
        find.textContaining(InputModeRules.touchLines.first),
        findsOneWidget,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: TutorialOverlay(onDone: () {}, inputMode: InputMode.keyboard),
        ),
      );
      expect(
        find.textContaining(InputModeRules.keyboardLines.first),
        findsOneWidget,
      );
    });

    testWidgets('玩法页同时列出触屏和键盘说明', (tester) async {
      await _useTallView(tester);
      await tester.pumpWidget(const MaterialApp(home: HowToPlayPage()));
      expect(
        find.textContaining(InputModeRules.touchLines.first),
        findsOneWidget,
      );
      expect(
        find.textContaining(InputModeRules.keyboardLines.first),
        findsOneWidget,
      );
    });
  });
}
