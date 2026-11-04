import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:macaron_girlfriend_run/data/enemy_kind.dart';
import 'package:macaron_girlfriend_run/data/game_models.dart';
import 'package:macaron_girlfriend_run/data/save_service.dart';
import 'package:macaron_girlfriend_run/game/entities/entities.dart';
import 'package:macaron_girlfriend_run/game/player/hero_sprites.dart';
import 'package:macaron_girlfriend_run/ui/home_page.dart';
import 'package:macaron_girlfriend_run/ui/macaron_dialogs.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('stride animation depends on travelled distance at 30/60/120 FPS', () {
    for (final fps in [30, 60, 120]) {
      final animator = HeroPoseAnimator();
      for (var i = 0; i < fps; i++) {
        animator.move(60 / fps, 1 / fps, running: true);
      }
      expect(animator.stridePhase, closeTo(60 / 96, 0.00001));
      expect(animator.runPose, HeroPose.run3);
      expect(animator.runBob.abs(), lessThanOrEqualTo(1.4));
      expect(animator.runLean, inInclusiveRange(0.023, 0.047));
    }
  });

  test('enemy patrol deforms and a hopper compresses on landing', () {
    final enemy = SoftEnemy(
      position: Vector2(50, 100),
      leftBound: 0,
      rightBound: 500,
      difficulty: 0,
      kind: EnemyKind.walker,
    );
    final initial = enemy.visualSquash;
    for (var i = 0; i < 10; i++) {
      enemy.update(1 / 60);
    }
    expect(enemy.visualSquash, isNot(closeTo(initial, 0.001)));
    final hopper = SoftEnemy(
      position: Vector2(50, 100),
      leftBound: 0,
      rightBound: 500,
      difficulty: 0,
      kind: EnemyKind.hopper,
    );
    var sawLanding = false;
    for (var i = 0; i < 120; i++) {
      final before = hopper.position.y;
      hopper.update(1 / 120);
      if (before < 99.9 && hopper.position.y == 100) {
        sawLanding = true;
        expect(hopper.visualSquash, greaterThan(1.07));
        break;
      }
    }
    expect(sawLanding, isTrue);
  });

  test(
    'pickup and death visuals end in 300 ms without changing collision state',
    () {
      final pop = CoinPopVisual(position: Vector2.zero());
      final enemy = SoftEnemy(
        position: Vector2.zero(),
        leftBound: 0,
        rightBound: 100,
        difficulty: 0,
      );
      enemy.takeStomp();
      expect(enemy.dead, isTrue);
      final fade = EnemyDeathVisual(enemy);
      pop.update(0.15);
      fade.update(0.14);
      expect(pop.progress, closeTo(0.5, 0.001));
      expect(fade.progress, closeTo(0.5, 0.001));
      pop.update(0.15);
      fade.update(0.14);
      expect(pop.progress, 1);
      expect(fade.progress, 1);
    },
  );

  test('checkpoint waves and spring compresses then rebounds', () {
    final flag = CheckpointPad(position: Vector2.zero());
    final initial = flag.waveOffset;
    flag.update(0.3);
    expect(flag.waveOffset, isNot(initial));
    expect(flag.waveOffset.abs(), lessThanOrEqualTo(3));
    final spring = SpringPad(position: Vector2.zero())..bounce();
    expect(spring.visualHeightFactor, closeTo(0.6, 0.001));
    spring.update(1 / 6);
    expect(spring.visualHeightFactor, greaterThan(1));
    spring.update(1);
    expect(spring.visualHeightFactor, 1);
  });

  testWidgets('celebration reveals lines and counts score over 800 ms', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: CelebrationBody(body: '第一行\n分数 1000\n第三行')),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('分数 1000'), findsNothing);
    final opacities = tester.widgetList<Opacity>(find.byType(Opacity)).toList();
    expect(opacities[0].opacity, 1);
    expect(opacities[2].opacity, 0);
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('分数 1000'), findsOneWidget);
  });

  testWidgets('level tile scales down while held and resets on release', (
    tester,
  ) async {
    var tapped = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LevelTileFeedback(
            onTap: () => tapped++,
            child: const SizedBox(width: 100, height: 100, child: Text('关卡')),
          ),
        ),
      ),
    );
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('关卡')),
    );
    await tester.pump(const Duration(milliseconds: 120));
    expect(
      tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale,
      0.96,
    );
    await gesture.up();
    await tester.pump();
    expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale, 1);
    expect(tapped, 1);
  });

  testWidgets('world selection animates the heading change', (tester) async {
    SharedPreferences.setMockInitialValues({
      'sound_on': false,
      'music_on': false,
      'haptic_on': false,
    });
    await SaveService.instance.init();
    await tester.pumpWidget(const MaterialApp(home: WorldMapPage()));
    final first = WorldCatalog.paletteOf(0).displayName;
    final next = WorldCatalog.paletteOf(1).displayName;
    expect(find.text('$first · 选关'), findsOneWidget);
    await tester.tap(find.text(next).first);
    await tester.pump();
    expect(find.text('$next · 选关'), findsOneWidget);
    expect(find.byType(AnimatedSwitcher), findsWidgets);
    await tester.pumpAndSettle();
    expect(find.text('$first · 选关'), findsNothing);
  });
}
