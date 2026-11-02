import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:macaron_girlfriend_run/ui/controls.dart';

final _wheelFinder = find.byWidgetPredicate(
  (w) => w.runtimeType.toString() == '_MoveWheel',
);

Widget _controls({
  required void Function(bool) onLeft,
  required void Function(bool) onRight,
}) => MaterialApp(
  home: Scaffold(
    body: Stack(
      children: [
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: TouchControls(
            onLeft: onLeft,
            onRight: onRight,
            onRun: (_) {},
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

    await gesture.moveTo(center + const Offset(40, 0));
    expect(log, ['Rtrue']);
    await gesture.moveTo(center + const Offset(-40, 0));
    expect(log, ['Rtrue', 'Rfalse', 'Ltrue']);
    await gesture.moveTo(center + const Offset(2, 0));
    expect(log.last, 'Lfalse', reason: 'back to the dead zone releases');
    await gesture.moveTo(center + const Offset(40, 0));
    await gesture.up();
    expect(log.last, 'Rfalse', reason: 'lifting the finger releases');
    await tester.pump();
  });

  testWidgets('buttons sit in the thumb zones and never overlap', (
    tester,
  ) async {
    for (final size in [
      const Size(812, 375),
      const Size(667, 375),
      const Size(568, 320),
    ]) {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      await tester.pumpWidget(_controls(onLeft: (_) {}, onRight: (_) {}));
      expect(tester.takeException(), isNull, reason: '$size');

      final rects = <String, Rect>{
        for (final label in ['射击', '闪冲', '蹲', '跑', '跳', '换'])
          label: tester.getRect(find.text(label)),
      };
      final wheel = tester.getRect(_wheelFinder);

      expect(wheel.center.dx, lessThan(size.width * 0.3), reason: '$size');
      for (final entry in rects.entries) {
        expect(
          entry.value.center.dx,
          greaterThan(size.width * 0.5),
          reason: '${entry.key} $size',
        );
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
      final jump = rects['跳']!;
      for (final other in ['射击', '闪冲', '蹲', '跑', '换']) {
        // 最上方的键可以在跳跃键正上方略偏右，但不能跑到它右边去。
        expect(
          rects[other]!.center.dx,
          lessThan(jump.center.dx + 40),
          reason: '$other should stay above or left of jump ($size)',
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
