import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:macaron_girlfriend_run/ui/controls.dart';

void main() {
  testWidgets('all mobile gameplay controls fit narrow portrait screens', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    for (final width in [320.0, 360.0, 390.0]) {
      tester.view.physicalSize = Size(width, 720);
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
                    skillLabel: '闪冲',
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull, reason: 'viewport width $width');
      for (final label in ['射击', '闪冲', '蹲', '跑', '跳']) {
        expect(
          find.text(label),
          findsOneWidget,
          reason: 'viewport width $width',
        );
      }
    }
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}
