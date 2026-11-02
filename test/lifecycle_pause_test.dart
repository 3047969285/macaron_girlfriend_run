import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:macaron_girlfriend_run/data/save_service.dart';
import 'package:macaron_girlfriend_run/ui/play_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'sound_on': false,
      'music_on': false,
      'haptic_on': false,
      'tutorial_done': true,
    });
    await SaveService.instance.init();
  });

  testWidgets('a transient inactive state does not pause; going hidden does', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 400);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(home: PlayPage(worldIndex: 0, levelIndex: 0)),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('切到后台啦'), findsNothing);

    // 点技能、跳跃或系统弹层造成的瞬时失焦：不暂停。
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(find.text('切到后台啦'), findsNothing);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(find.text('切到后台啦'), findsNothing);

    // 真正切到后台：暂停。
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    await tester.pump();
    expect(find.text('切到后台啦'), findsOneWidget);

    // 瞬间离开、马上回来：自动继续，不卡在暂停画面。
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(find.text('切到后台啦'), findsNothing);
  });

  testWidgets(
    'a long absence keeps the pause screen until the player returns',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(800, 400);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        const MaterialApp(home: PlayPage(worldIndex: 0, levelIndex: 0)),
      );
      await tester.pump(const Duration(milliseconds: 300));

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      await tester.pump();
      expect(find.text('切到后台啦'), findsOneWidget);

      // 真实等待超过“瞬间离开”的阈值（Stopwatch 不受测试假时钟控制）。
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 2200)),
      );
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(find.text('切到后台啦'), findsOneWidget);
    },
  );
}
