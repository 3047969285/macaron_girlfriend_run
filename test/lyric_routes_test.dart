import 'package:flutter_test/flutter_test.dart';
import 'package:macaron_girlfriend_run/data/level_catalog.dart';

void main() {
  test('each song has playable lyric routes in all three chapters', () {
    var levelsWithLyricRoutes = 0;
    for (var world = 0; world < 9; world++) {
      final signatures = <Set<String>>[];
      for (var chapter = 0; chapter < 3; chapter++) {
        final found = <String>{};
        for (var level = 0; level < 11; level++) {
          if (level * 3 ~/ 11 != chapter) continue;
          final base = LevelCatalog.loadBase(world, level);
          final full = LevelCatalog.load(world, level);
          final ground = base.height - 3;
          expect(full.rows[ground], base.rows[ground]);
          expect(full.rows[ground + 1], base.rows[ground + 1]);
          expect(full.rows[ground + 2], base.rows[ground + 2]);
          final scenes = LevelCatalog.scenesOf(world, level);
          if (scenes.any((scene) => scene.lyricRoute != null)) {
            levelsWithLyricRoutes++;
          }
          for (final scene in scenes) {
            if (scene.lyricRoute == null) continue;
            final solids = scene.cells.entries
                .where((e) => '=?'.contains(e.value))
                .toList();
            expect(solids.length, greaterThanOrEqualTo(7));
            for (final entry in solids) {
              expect(full.rows[entry.key.$2][entry.key.$1], entry.value);
            }
            final origin = solids
                .map((e) => e.key.$1)
                .reduce((a, b) => a < b ? a : b);
            final shape =
                solids
                    .map((e) => '${e.key.$1 - origin}:${ground - e.key.$2}')
                    .toList()
                  ..sort();
            found.add(shape.join(','));
          }
        }
        expect(found, isNotEmpty, reason: 'world $world chapter $chapter');
        signatures.add(found);
      }
      expect(
        signatures.first.difference(signatures.last),
        isNotEmpty,
        reason:
            'world $world should change its playable route between chapters',
      );
    }
    expect(levelsWithLyricRoutes, 99);
  });
}
