import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:macaron_girlfriend_run/data/save_service.dart';
import 'package:macaron_girlfriend_run/ui/home_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('settings expose attribution for every bundled music track', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await SaveService.instance.init();

    await tester.pumpWidget(const MaterialApp(home: SettingsPage()));
    await tester.tap(find.text('音乐来源与授权'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Slow Jam — Kevin MacLeod'), findsOneWidget);
    expect(find.textContaining('Smooth Lovin — Kevin MacLeod'), findsOneWidget);
    expect(find.textContaining('Morning — Kevin MacLeod'), findsOneWidget);
    expect(
      find.textContaining('Creative Commons Attribution 4.0 International'),
      findsOneWidget,
    );
  });
}
