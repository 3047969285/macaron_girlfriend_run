// 手机竖屏遮挡修复验收测试，对应 docs/手机遮挡/需求与接口.md。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:macaron_girlfriend_run/ui/game_viewport.dart';
import 'package:macaron_girlfriend_run/ui/play_page.dart';

Future<void> _setView(WidgetTester tester, Size size) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

double _hintOpacity(WidgetTester tester) => tester
    .widget<AnimatedOpacity>(
      find.ancestor(of: find.text('横置手机或加宽窗口'), matching: find.byType(AnimatedOpacity)),
    )
    .opacity;

void main() {
  testWidgets('Boss 血条紧凑，不拉满整行', (tester) async {
    await _setView(tester, const Size(800, 400));
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: 800,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [Align(alignment: Alignment.topCenter, child: BossHpBar(hp: 2, maxHp: 3, enraged: false, counterWindow: false))],
              ),
            ),
          ),
        ),
      ),
    );
    final size = tester.getSize(find.byType(BossHpBar));
    expect(size.width, lessThanOrEqualTo(260));
    expect(size.height, lessThanOrEqualTo(40));
    expect(find.text('Boss · 踩踏破防'), findsOneWidget);
    expect(find.text('2 / 3'), findsOneWidget);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: BossHpBar(hp: 1, maxHp: 3, enraged: true, counterWindow: false))),
      ),
    );
    expect(find.text('Boss 狂暴中'), findsOneWidget);
  });

  testWidgets('竖屏提示 4 秒后淡出，横屏没有提示', (tester) async {
    await _setView(tester, const Size(400, 800));
    await tester.pumpWidget(
      const MaterialApp(home: GameViewport(child: SizedBox.expand())),
    );
    expect(_hintOpacity(tester), 1);
    await tester.pump(const Duration(milliseconds: 4500));
    await tester.pump(const Duration(milliseconds: 400));
    expect(_hintOpacity(tester), 0);

    await _setView(tester, const Size(800, 400));
    await tester.pumpWidget(
      const MaterialApp(home: GameViewport(key: ValueKey('landscape'), child: SizedBox.expand())),
    );
    expect(find.text('横置手机或加宽窗口'), findsNothing);
  });
}
