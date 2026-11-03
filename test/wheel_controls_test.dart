import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:macaron_girlfriend_run/ui/controls.dart';

final _wheelFinder = find.byKey(moveWheelKey);

Widget _controls({
  void Function(bool)? onLeft,
  void Function(bool)? onRight,
  void Function(bool)? onRun,
}) => MaterialApp(
  home: Scaffold(
    body: Stack(
      children: [
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: TouchControls(
            onLeft: onLeft ?? (_) {},
            onRight: onRight ?? (_) {},
            onRun: onRun ?? (_) {},
            onDuck: (_) {},
            onJumpHeld: (_) {},
            onSkill: () {},
            onCycleSkill: () {},
            onShoot: (_) {},
            skillLabel: '闪冲',
          ),
        ),
      ],
    ),
  ),
);

void main() {
  testWidgets('the stick floats: any touch on the left half is the centre', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(812, 375);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final log = <String>[];
    await tester.pumpWidget(
      _controls(onLeft: (v) => log.add('L$v'), onRight: (v) => log.add('R$v')),
    );
    final home = tester.getRect(_wheelFinder).center;

    // 离小圆很远（上方 90、右边 120）的地方落指，也算起点；圆跟到手指下面。
    final start = home + const Offset(120, -90);
    final gesture = await tester.startGesture(start);
    await tester.pump();
    expect(log, isEmpty);
    expect(
      (tester.getRect(_wheelFinder).center - start).distance,
      lessThan(2),
      reason: 'the wheel follows the finger',
    );
    await gesture.moveTo(start + const Offset(-18, 0));
    expect(log, ['Ltrue']);
    await gesture.up();
    await tester.pump();
    expect(log.last, 'Lfalse');
    expect(tester.getRect(_wheelFinder).center, home, reason: 'back home');
  });

  testWidgets('the wheel moves left and right and releases on lift', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(812, 375);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final log = <String>[];
    await tester.pumpWidget(
      _controls(onLeft: (v) => log.add('L$v'), onRight: (v) => log.add('R$v')),
    );

    final center = tester.getRect(_wheelFinder).center;
    final gesture = await tester.startGesture(center);
    expect(log, isEmpty, reason: 'the centre is the dead zone');

    await gesture.moveTo(center + const Offset(18, 0));
    expect(log, ['Rtrue']);
    await gesture.moveTo(center + const Offset(-18, 0));
    expect(log, ['Rtrue', 'Rfalse', 'Ltrue']);
    await gesture.moveTo(center + const Offset(2, 0));
    expect(log.last, 'Lfalse', reason: 'back to the dead zone releases');
    await gesture.moveTo(center + const Offset(18, 0));
    await gesture.up();
    expect(log.last, 'Rfalse', reason: 'lifting the finger releases');
    await tester.pump();
  });

  testWidgets('pushing the wheel all the way runs; a partial push walks', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(812, 375);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final runs = <bool>[];
    await tester.pumpWidget(_controls(onRun: runs.add));

    final center = tester.getRect(_wheelFinder).center;
    final gesture = await tester.startGesture(center);
    await gesture.moveTo(center + const Offset(14, 0));
    expect(runs, isEmpty, reason: 'a gentle push only walks');
    await gesture.moveTo(center + const Offset(60, 0));
    expect(runs, [true], reason: 'a full push runs');
    await gesture.moveTo(center + const Offset(14, 0));
    expect(runs, [true, false], reason: 'easing off stops the run');
    await gesture.up();
  });

  testWidgets('jump sits in the bottom-right corner and nothing overlaps', (
    tester,
  ) async {
    for (final size in [
      const Size(812, 375),
      const Size(667, 375),
      const Size(568, 320),
    ]) {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      await tester.pumpWidget(_controls());
      expect(tester.takeException(), isNull, reason: '$size');

      final rects = <String, Rect>{
        for (final label in ['射击', '闪冲', '蹲', '跳', '换'])
          label: tester.getRect(find.text(label)),
      };
      final wheel = tester.getRect(_wheelFinder);

      expect(wheel.center.dx, lessThan(size.width * 0.3), reason: '$size');
      // 轮盘不能太大：直径不超过屏幕高度的 38%，不遮挡人物。
      expect(
        wheel.width,
        lessThanOrEqualTo(size.height * 0.38),
        reason: '$size',
      );

      final jump = rects['跳']!;
      expect(find.text('跑'), findsNothing);
      expect(jump.center.dx, greaterThan(size.width * 0.8));
      expect(jump.center.dy, greaterThan(rects['蹲']!.center.dy));
      expect(jump.center.dy, greaterThan(rects['闪冲']!.center.dy));

      for (final label in ['射击', '闪冲', '蹲', '跳', '换']) {
        expect(
          rects[label]!.center.dx,
          greaterThan(size.width * 0.5),
          reason: '$label $size',
        );
      }
      for (final entry in rects.entries) {
        expect(
          entry.value.bottom,
          lessThanOrEqualTo(size.height),
          reason: '${entry.key} $size',
        );
        expect(
          entry.value.top,
          greaterThanOrEqualTo(0),
          reason: '${entry.key} $size',
        );
      }
      final labels = rects.keys.toList();
      for (var i = 0; i < labels.length; i++) {
        for (var j = i + 1; j < labels.length; j++) {
          expect(
            (rects[labels[i]]!.center - rects[labels[j]]!.center).distance,
            greaterThan(30),
            reason: '${labels[i]} vs ${labels[j]} overlap at $size',
          );
        }
      }
    }
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}
