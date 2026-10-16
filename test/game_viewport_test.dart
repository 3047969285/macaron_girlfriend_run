import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:macaron_girlfriend_run/ui/game_viewport.dart';

void main() {
  testWidgets(
    'portrait rotates layout and insets while retaining child state',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 720);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var geometryChanges = 0;
      var taps = 0;
      late MediaQueryData logical;
      final childKey = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 720),
              padding: EdgeInsets.fromLTRB(10, 20, 30, 40),
            ),
            child: GameViewport(
              onGeometryChanged: () => geometryChanges++,
              child: Builder(
                key: childKey,
                builder: (context) {
                  logical = MediaQuery.of(context);
                  return Center(
                    child: TextButton(
                      onPressed: () => taps++,
                      child: const Text('操作'),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );
      expect(logical.size, const Size(720, 320));
      expect(logical.padding, const EdgeInsets.fromLTRB(20, 30, 40, 10));
      final element = childKey.currentContext;
      await tester.tap(find.text('操作'));
      expect(taps, 1);
      tester.view.physicalSize = const Size(720, 320);
      await tester.pump();
      expect(childKey.currentContext, same(element));
      expect(geometryChanges, 1);
      expect(
        tester.widget<RotatedBox>(find.byType(RotatedBox)).quarterTurns,
        0,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
