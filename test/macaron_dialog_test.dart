import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:macaron_girlfriend_run/ui/macaron_dialogs.dart';
import 'package:macaron_girlfriend_run/ui/play_page.dart';

void main() {
  final longBody = List.generate(
    14,
    (i) => '第 ${i + 1} 条说明，文字要足够长才会折行',
  ).join('\n');

  Future<void> openDialog(WidgetTester tester, Size size) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => showMacaronDialog<void>(
                  context: context,
                  title: '怎么玩',
                  body: longBody,
                  actions: [
                    MacaronDialogAction(
                      label: '开始冒险',
                      primary: true,
                      onPressed: (ctx) => Navigator.pop(ctx),
                    ),
                  ],
                ),
                child: const Text('打开'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();
  }

  testWidgets('long dialog keeps title and primary action on a short phone', (
    tester,
  ) async {
    const phone = Size(812, 375);
    await openDialog(tester, phone);
    final title = tester.getRect(find.text('怎么玩'));
    final action = tester.getRect(find.text('开始冒险'));
    expect(title.top, greaterThanOrEqualTo(0));
    expect(action.bottom, lessThanOrEqualTo(phone.height));
    expect(action.top, greaterThanOrEqualTo(title.bottom));
    expect(tester.takeException(), isNull);

    // 主按钮在可见区域内，点击能关闭弹窗。
    await tester.tap(find.text('开始冒险'));
    await tester.pumpAndSettle();
    expect(find.text('怎么玩'), findsNothing);
  });

  testWidgets('tutorial overlay keeps its start button on a short phone', (
    tester,
  ) async {
    const phone = Size(812, 375);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = phone;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var started = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: TutorialOverlay(onDone: () => started++)),
      ),
    );
    final title = tester.getRect(find.text('怎么玩'));
    final action = tester.getRect(find.text('开始冒险'));
    expect(title.top, greaterThanOrEqualTo(0));
    expect(action.bottom, lessThanOrEqualTo(phone.height));
    await tester.tap(find.text('开始冒险'));
    expect(started, 1);
    expect(tester.takeException(), isNull);

    // 说明列表在中间滚动，最后一条可以滚到可见区域。
    final last = find.text('• 看头顶预警再出手', skipOffstage: false);
    expect(last, findsOneWidget);
    await tester.ensureVisible(last);
    await tester.pump();
    expect(
      tester.getRect(last).bottom,
      lessThanOrEqualTo(tester.getRect(find.text('开始冒险')).top),
    );
  });

  testWidgets('short dialog is unchanged on a tall screen', (tester) async {
    await openDialog(tester, const Size(800, 900));
    final action = tester.getRect(find.text('开始冒险'));
    expect(action.bottom, lessThanOrEqualTo(900));
    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
