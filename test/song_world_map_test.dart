import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:macaron_girlfriend_run/data/game_models.dart';
import 'package:macaron_girlfriend_run/data/save_service.dart';
import 'package:macaron_girlfriend_run/data/song_profile.dart';
import 'package:macaron_girlfriend_run/ui/home_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('world selection shows its song and completed level count', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await SaveService.instance.init();
    await SaveService.instance.setStars(SaveService.toGlobal(0, 0), 2);
    await tester.pumpWidget(const MaterialApp(home: WorldMapPage()));
    expect(find.text('♪ ${SongProfile.of(0).title}'), findsOneWidget);
    expect(
      find.text('已通关 1 / ${GameConstants.levelsPerWorld}'),
      findsOneWidget,
    );
    await tester.tap(find.text(WorldCatalog.paletteOf(1).displayName).first);
    await tester.pumpAndSettle();
    expect(find.text('♪ ${SongProfile.of(1).title}'), findsOneWidget);
    expect(
      find.text('已通关 0 / ${GameConstants.levelsPerWorld}'),
      findsOneWidget,
    );
  });

  testWidgets('world selection fits small portrait and landscape screens', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await SaveService.instance.init();
    for (final size in [const Size(320, 568), const Size(568, 320)]) {
      await tester.binding.setSurfaceSize(size);
      await tester.pumpWidget(const MaterialApp(home: WorldMapPage()));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text('♪ ${SongProfile.of(0).title}'), findsOneWidget);
    }
    await tester.binding.setSurfaceSize(null);
  });
}
