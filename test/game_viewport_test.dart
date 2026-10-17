import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:macaron_girlfriend_run/main.dart';
import 'package:macaron_girlfriend_run/ui/game_viewport.dart';

void main() {
  testWidgets(
    'app shell lays out every page in landscape on a portrait phone',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 720);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      late Size menuSize;
      late Size nestedSize;
      await tester.pumpWidget(
        MaterialApp(
          builder: macaronAppShell,
          home: Builder(
            builder: (context) {
              menuSize = MediaQuery.of(context).size;
              // 游戏页自带 GameViewport：外壳已经转成横屏，内层不能再转一次。
              return GameViewport(
                showHint: false,
                child: Builder(
                  builder: (inner) {
                    nestedSize = MediaQuery.of(inner).size;
                    return const SizedBox.expand();
                  },
                ),
              );
            },
          ),
        ),
      );
      expect(menuSize, const Size(720, 320));
      expect(nestedSize, const Size(720, 320));
      final turns = tester
          .widgetList<RotatedBox>(find.byType(RotatedBox))
          .map((box) => box.quarterTurns)
          .toList();
      expect(turns.where((t) => t == 1), hasLength(1));
      expect(turns.where((t) => t == 0), isNotEmpty);
      expect(find.text('横置手机或加宽窗口'), findsOneWidget);

      tester.view.physicalSize = const Size(720, 320);
      await tester.pump();
      expect(menuSize, const Size(720, 320));
      expect(
        tester
            .widgetList<RotatedBox>(find.byType(RotatedBox))
            .every((box) => box.quarterTurns == 0),
        isTrue,
      );
      expect(find.text('横置手机或加宽窗口'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

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
